/*
 * Copyright (C) 2015-2017 Netronome Systems, Inc.
 *
 * This software is dual licensed under the GNU General License Version 2,
 * June 1991 as shown in the file COPYING in the top-level directory of this
 * source tree or the BSD 2-Clause License provided below.  You have the
 * option to license this software under the complete terms of either license.
 *
 * The BSD 2-Clause License:
 *
 *     Redistribution and use in source and binary forms, with or
 *     without modification, are permitted provided that the following
 *     conditions are met:
 *
 *      1. Redistributions of source code must retain the above
 *         copyright notice, this list of conditions and the following
 *         disclaimer.
 *
 *      2. Redistributions in binary form must reproduce the above
 *         copyright notice, this list of conditions and the following
 *         disclaimer in the documentation and/or other materials
 *         provided with the distribution.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 * EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
 * MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
 * NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS
 * BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
 * ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
 * CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 */

/*
 * nfp_nsp.c
 * Author: Jakub Kicinski <jakub.kicinski@netronome.com>
 *         Jason McMullan <jason.mcmullan@netronome.com>
 */

#include <linux/bitfield.h>
#include <linux/delay.h>
#include <linux/firmware.h>
#include <linux/kernel.h>
#include <linux/kthread.h>
#include <linux/sizes.h>
#include <linux/slab.h>

#define NFP_SUBSYS "nfp_nsp"

#include "nfp.h"
#include "nfp_cpp.h"
#include "nfp_nsp.h"

/* Offsets relative to the CSR base */
#define NSP_STATUS		0x00
#define   NSP_STATUS_MAGIC	GENMASK_ULL(63, 48)
#define   NSP_STATUS_MAJOR	GENMASK_ULL(47, 44)
#define   NSP_STATUS_MINOR	GENMASK_ULL(43, 32)
#define   NSP_STATUS_CODE	GENMASK_ULL(31, 16)
#define   NSP_STATUS_RESULT	GENMASK_ULL(15, 8)
#define   NSP_STATUS_BUSY	BIT_ULL(0)

#define NSP_COMMAND		0x08
#define   NSP_COMMAND_OPTION	GENMASK_ULL(63, 32)
#define   NSP_COMMAND_CODE	GENMASK_ULL(31, 16)
#define   NSP_COMMAND_START	BIT_ULL(0)

/* CPP address to retrieve the data from */
#define NSP_BUFFER		0x10
#define   NSP_BUFFER_CPP	GENMASK_ULL(63, 40)
#define   NSP_BUFFER_ADDRESS	GENMASK_ULL(39, 0)

#define NSP_DFLT_BUFFER		0x18
#define   NSP_DFLT_BUFFER_CPP	GENMASK_ULL(63, 40)
#define   NSP_DFLT_BUFFER_ADDRESS	GENMASK_ULL(39, 0)

#define NSP_DFLT_BUFFER_CONFIG	0x20
#define   NSP_DFLT_BUFFER_SIZE_MB	GENMASK_ULL(7, 0)

#define NSP_MAGIC		0xab10
#define NSP_MAJOR		0
#define NSP_MINOR		8

#define NSP_CODE_MAJOR		GENMASK(15, 12)
#define NSP_CODE_MINOR		GENMASK(11, 0)

enum nfp_nsp_cmd {
	SPCODE_NOOP		= 0, /* No operation */
	SPCODE_SOFT_RESET	= 1, /* Soft reset the NFP */
	SPCODE_FW_DEFAULT	= 2, /* Load default (UNDI) FW */
	SPCODE_PHY_INIT		= 3, /* Initialize the PHY */
	SPCODE_MAC_INIT		= 4, /* Initialize the MAC */
	SPCODE_PHY_RXADAPT	= 5, /* Re-run PHY RX Adaptation */
	SPCODE_FW_LOAD		= 6, /* Load fw from buffer, len in option */
	SPCODE_ETH_RESCAN	= 7, /* Rescan ETHs, write ETH_TABLE to buf */
	SPCODE_ETH_CONTROL	= 8, /* Update media config from buffer */
	SPCODE_NSP_SENSORS	= 12, /* Read NSP sensor(s) */
	SPCODE_NSP_IDENTIFY	= 13, /* Read NSP version */
};

static const struct {
	int code;
	const char *msg;
} nsp_errors[] = {
	{ 6010, "could not map to phy for port" },
	{ 6011, "not an allowed rate/lanes for port" },
	{ 6012, "not an allowed rate/lanes for port" },
	{ 6013, "high/low error, change other port first" },
	{ 6014, "config not found in flash" },
};

struct nfp_nsp {
	struct nfp_cpp *cpp;
	struct nfp_resource *res;
	struct {
		u16 major;
		u16 minor;
	} ver;

	/* Eth table config state */
	bool modified;
	unsigned int idx;
	void *entries;
};

struct nfp_cpp *nfp_nsp_cpp(struct nfp_nsp *state)
{
	return state->cpp;
}

bool nfp_nsp_config_modified(struct nfp_nsp *state)
{
	return state->modified;
}

void nfp_nsp_config_set_modified(struct nfp_nsp *state, bool modified)
{
	state->modified = modified;
}

void *nfp_nsp_config_entries(struct nfp_nsp *state)
{
	return state->entries;
}

unsigned int nfp_nsp_config_idx(struct nfp_nsp *state)
{
	return state->idx;
}

void
nfp_nsp_config_set_state(struct nfp_nsp *state, void *entries, unsigned int idx)
{
	state->entries = entries;
	state->idx = idx;
}

void nfp_nsp_config_clear_state(struct nfp_nsp *state)
{
	state->entries = NULL;
	state->idx = 0;
}

static void nfp_nsp_print_extended_error(struct nfp_nsp *state, u32 ret_val)
{
	int i;

	if (!ret_val)
		return;

	for (i = 0; i < ARRAY_SIZE(nsp_errors); i++)
		if (ret_val == nsp_errors[i].code)
			nfp_err(state->cpp, "err msg: %s\n", nsp_errors[i].msg);
}

static int nfp_nsp_check(struct nfp_nsp *state)
{
	struct nfp_cpp *cpp = state->cpp;
	u64 nsp_status, reg;
	u32 nsp_cpp;
	int err;

	nsp_cpp = nfp_resource_cpp_id(state->res);
	nsp_status = nfp_resource_address(state->res) + NSP_STATUS;

	err = nfp_cpp_readq(cpp, nsp_cpp, nsp_status, &reg);
	if (err < 0)
		return err;

	if (FIELD_GET(NSP_STATUS_MAGIC, reg) != NSP_MAGIC) {
		nfp_err(cpp, "Cannot detect NFP Service Processor\n");
		return -ENODEV;
	}

	state->ver.major = FIELD_GET(NSP_STATUS_MAJOR, reg);
	state->ver.minor = FIELD_GET(NSP_STATUS_MINOR, reg);

	if (state->ver.major != NSP_MAJOR) {
		nfp_err(cpp, "Unsupported ABI %u.%u\n",
			state->ver.major, state->ver.minor);
		return -EINVAL;
	}
	if (state->ver.minor < NSP_MINOR) {
		nfp_err(cpp, "ABI too old to support NIC operation (%u.%u < %u.%u), please update the management FW on the flash\n",
			NSP_MAJOR, state->ver.minor, NSP_MAJOR, NSP_MINOR);
		return -EINVAL;
	}

	if (reg & NSP_STATUS_BUSY) {
		nfp_err(cpp, "Service processor busy!\n");
		return -EBUSY;
	}

	return 0;
}

/**
 * nfp_nsp_open() - Prepare for communication and lock the NSP resource.
 * @cpp:	NFP CPP Handle
 */
struct nfp_nsp *nfp_nsp_open(struct nfp_cpp *cpp)
{
	struct nfp_resource *res;
	struct nfp_nsp *state;
	int err;

	res = nfp_resource_acquire(cpp, NFP_RESOURCE_NSP);
	if (IS_ERR(res))
		return (void *)res;

	state = kzalloc(sizeof(*state), GFP_KERNEL);
	if (!state) {
		nfp_resource_release(res);
		return ERR_PTR(-ENOMEM);
	}
	state->cpp = cpp;
	state->res = res;

	err = nfp_nsp_check(state);
	if (err) {
		nfp_nsp_close(state);
		return ERR_PTR(err);
	}

	return state;
}

/**
 * nfp_nsp_close() - Clean up and unlock the NSP resource.
 * @state:	NFP SP state
 */
void nfp_nsp_close(struct nfp_nsp *state)
{
	nfp_resource_release(state->res);
	kfree(state);
}

u16 nfp_nsp_get_abi_ver_major(struct nfp_nsp *state)
{
	return state->ver.major;
}

u16 nfp_nsp_get_abi_ver_minor(struct nfp_nsp *state)
{
	return state->ver.minor;
}

static int
nfp_nsp_wait_reg(struct nfp_cpp *cpp, u64 *reg,
		 u32 nsp_cpp, u64 addr, u64 mask, u64 val)
{
	const unsigned long wait_until = jiffies + 30 * HZ;
	int err;

	for (;;) {
		const unsigned long start_time = jiffies;

		err = nfp_cpp_readq(cpp, nsp_cpp, addr, reg);
		if (err < 0)
			return err;

		if ((*reg & mask) == val)
			return 0;

		msleep(25);

		if (time_after(start_time, wait_until))
			return -ETIMEDOUT;
	}
}

/**
 * nfp_nsp_command() - Execute a command on the NFP Service Processor
 * @state:	NFP SP state
 * @code:	NFP SP Command Code
 * @option:	NFP SP Command Argument
 * @buff_cpp:	NFP SP Buffer CPP Address info
 * @buff_addr:	NFP SP Buffer Host address
 *
 * Return: 0 for success with no result
 *
 *	 positive value for NSP completion with a result code
 *
 *	-EAGAIN if the NSP is not yet present
 *	-ENODEV if the NSP is not a supported model
 *	-EBUSY if the NSP is stuck
 *	-EINTR if interrupted while waiting for completion
 *	-ETIMEDOUT if the NSP took longer than 30 seconds to complete
 */
static int nfp_nsp_command(struct nfp_nsp *state, u16 code, u32 option,
			   u32 buff_cpp, u64 buff_addr)
{
	u64 reg, ret_val, nsp_base, nsp_buffer, nsp_status, nsp_command;
	struct nfp_cpp *cpp = state->cpp;
	u32 nsp_cpp;
	int err;

	nsp_cpp = nfp_resource_cpp_id(state->res);
	nsp_base = nfp_resource_address(state->res);
	nsp_status = nsp_base + NSP_STATUS;
	nsp_command = nsp_base + NSP_COMMAND;
	nsp_buffer = nsp_base + NSP_BUFFER;

	err = nfp_nsp_check(state);
	if (err)
		return err;

	if (!FIELD_FIT(NSP_BUFFER_CPP, buff_cpp >> 8) ||
	    !FIELD_FIT(NSP_BUFFER_ADDRESS, buff_addr)) {
		nfp_err(cpp, "Host buffer out of reach %08x %016llx\n",
			buff_cpp, buff_addr);
		return -EINVAL;
	}

	err = nfp_cpp_writeq(cpp, nsp_cpp, nsp_buffer,
			     FIELD_PREP(NSP_BUFFER_CPP, buff_cpp >> 8) |
			     FIELD_PREP(NSP_BUFFER_ADDRESS, buff_addr));
	if (err < 0)
		return err;

	err = nfp_cpp_writeq(cpp, nsp_cpp, nsp_command,
			     FIELD_PREP(NSP_COMMAND_OPTION, option) |
			     FIELD_PREP(NSP_COMMAND_CODE, code) |
			     FIELD_PREP(NSP_COMMAND_START, 1));
	if (err < 0)
		return err;

	/* Wait for NSP_COMMAND_START to go to 0 */
	err = nfp_nsp_wait_reg(cpp, &reg,
			       nsp_cpp, nsp_command, NSP_COMMAND_START, 0);
	if (err) {
		nfp_err(cpp, "Error %d waiting for code 0x%04x to start\n",
			err, code);
		return err;
	}

	/* Wait for NSP_STATUS_BUSY to go to 0 */
	err = nfp_nsp_wait_reg(cpp, &reg,
			       nsp_cpp, nsp_status, NSP_STATUS_BUSY, 0);
	if (err) {
		nfp_err(cpp, "Error %d waiting for code 0x%04x to complete\n",
			err, code);
		return err;
	}

	err = nfp_cpp_readq(cpp, nsp_cpp, nsp_command, &ret_val);
	if (err < 0)
		return err;
	ret_val = FIELD_GET(NSP_COMMAND_OPTION, ret_val);

	err = FIELD_GET(NSP_STATUS_RESULT, reg);
	if (err) {
		nfp_warn(cpp, "Result (error) code set: %d (%d) command: %d\n",
			 -err, (int)ret_val, code);
		nfp_nsp_print_extended_error(state, ret_val);
		return -err;
	}

	return ret_val;
}

static int nfp_nsp_command_buf(struct nfp_nsp *nsp, u16 code, u32 option,
			       const void *in_buf, unsigned int in_size,
			       void *out_buf, unsigned int out_size)
{
	struct nfp_cpp *cpp = nsp->cpp;
	unsigned int max_size;
	u64 reg, cpp_buf;
	int ret, err;
	u32 cpp_id;

	if (nsp->ver.minor < 13) {
		nfp_err(cpp, "NSP: Code 0x%04x with buffer not supported (ABI %hu.%hu)\n",
			code, nsp->ver.major, nsp->ver.minor);
		return -EOPNOTSUPP;
	}

	err = nfp_cpp_readq(cpp, nfp_resource_cpp_id(nsp->res),
			    nfp_resource_address(nsp->res) +
			    NSP_DFLT_BUFFER_CONFIG,
			    &reg);
	if (err < 0)
		return err;

	max_size = max(in_size, out_size);
	if (FIELD_GET(NSP_DFLT_BUFFER_SIZE_MB, reg) * SZ_1M < max_size) {
		nfp_err(cpp, "NSP: default buffer too small for command 0x%04x (%llu < %u)\n",
			code, FIELD_GET(NSP_DFLT_BUFFER_SIZE_MB, reg) * SZ_1M,
			max_size);
		return -EINVAL;
	}

	err = nfp_cpp_readq(cpp, nfp_resource_cpp_id(nsp->res),
			    nfp_resource_address(nsp->res) +
			    NSP_DFLT_BUFFER,
			    &reg);
	if (err < 0)
		return err;

	cpp_id = FIELD_GET(NSP_DFLT_BUFFER_CPP, reg) << 8;
	cpp_buf = FIELD_GET(NSP_DFLT_BUFFER_ADDRESS, reg);

	if (in_buf && in_size) {
		err = nfp_cpp_write(cpp, cpp_id, cpp_buf, in_buf, in_size);
		if (err < 0)
			return err;
	}
	/* Zero out remaining part of the buffer */
	if (out_buf && out_size && out_size > in_size) {
		memset(out_buf, 0, out_size - in_size);
		err = nfp_cpp_write(cpp, cpp_id, cpp_buf + in_size,
				    out_buf, out_size - in_size);
		if (err < 0)
			return err;
	}

	ret = nfp_nsp_command(nsp, code, option, cpp_id, cpp_buf);
	if (ret < 0)
		return ret;

	if (out_buf && out_size) {
		err = nfp_cpp_read(cpp, cpp_id, cpp_buf, out_buf, out_size);
		if (err < 0)
			return err;
	}

	return ret;
}

static int
nfp_nsp_command_buf_dma_sg(struct nfp_nsp *nsp,
			   struct nfp_nsp_command_buf_arg *arg,
			   unsigned int max_size, unsigned int chunk_order,
			   unsigned int dma_order)
{
	struct nfp_cpp *cpp = nsp->cpp;
	struct nfp_nsp_dma_buf *desc;
	struct {
		dma_addr_t dma_addr;
		unsigned long len;
		void *chunk;
	} *chunks;
	size_t chunk_size, dma_size;
	dma_addr_t dma_desc;
	struct device *dev;
	unsigned long off;
	int i, ret, nseg;
	size_t desc_sz;

	chunk_size = BIT_ULL(chunk_order);
	dma_size = BIT_ULL(dma_order);
	nseg = DIV_ROUND_UP(max_size, chunk_size);

	chunks = kzalloc(array_size(sizeof(*chunks), nseg), GFP_KERNEL);
	if (!chunks)
		return -ENOMEM;

	off = 0;
	ret = -ENOMEM;
	for (i = 0; i < nseg; i++) {
		unsigned long coff;

		chunks[i].chunk = kmalloc(chunk_size,
					  GFP_KERNEL | __GFP_NOWARN);
		if (!chunks[i].chunk)
			goto exit_free_prev;

		chunks[i].len = min_t(u64, chunk_size, max_size - off);

		coff = 0;
		if (arg->in_size > off) {
			coff = min_t(u64, arg->in_size - off, chunk_size);
			memcpy(chunks[i].chunk, arg->in_buf + off, coff);
		}
		memset(chunks[i].chunk + coff, 0, chunk_size - coff);

		off += chunks[i].len;
	}

	dev = nfp_cpp_device(cpp)->parent;

	for (i = 0; i < nseg; i++) {
		dma_addr_t addr;

		addr = dma_map_single(dev, chunks[i].chunk, chunks[i].len,
				      DMA_BIDIRECTIONAL);
		chunks[i].dma_addr = addr;

		ret = dma_mapping_error(dev, addr);
		if (ret)
			goto exit_unmap_prev;

		if (WARN_ONCE(round_down(addr, dma_size) !=
			      round_down(addr + chunks[i].len - 1, dma_size),
			      "unaligned DMA address: %pad %lu %zd\n",
			      &addr, chunks[i].len, dma_size)) {
			ret = -EFAULT;
			i++;
			goto exit_unmap_prev;
		}
	}

	desc_sz = struct_size(desc, descs, nseg);
	desc = kmalloc(desc_sz, GFP_KERNEL);
	if (!desc) {
		ret = -ENOMEM;
		goto exit_unmap_all;
	}

	desc->chunk_cnt = cpu_to_le32(nseg);
	for (i = 0; i < nseg; i++) {
		desc->descs[i].size = cpu_to_le32(chunks[i].len);
		desc->descs[i].addr = cpu_to_le64(chunks[i].dma_addr);
	}

	dma_desc = dma_map_single(dev, desc, desc_sz, DMA_TO_DEVICE);
	ret = dma_mapping_error(dev, dma_desc);
	if (ret)
		goto exit_free_desc;

	arg->arg.dma = true;
	arg->arg.buf = dma_desc;
	ret = __nfp_nsp_command(nsp, &arg->arg);
	if (ret < 0)
		goto exit_unmap_desc;

	i = 0;
	off = 0;
	while (off < arg->out_size) {
		unsigned int len;

		len = min_t(u64, chunks[i].len, arg->out_size - off);
		memcpy(arg->out_buf + off, chunks[i].chunk, len);
		off += len;
		i++;
	}

exit_unmap_desc:
	dma_unmap_single(dev, dma_desc, desc_sz, DMA_TO_DEVICE);
exit_free_desc:
	kfree(desc);
exit_unmap_all:
	i = nseg;
exit_unmap_prev:
	while (--i >= 0)
		dma_unmap_single(dev, chunks[i].dma_addr, chunks[i].len,
				 DMA_BIDIRECTIONAL);
	i = nseg;
exit_free_prev:
	while (--i >= 0)
		kfree(chunks[i].chunk);
	kfree(chunks);
	if (ret < 0)
		nfp_err(cpp, "NSP: SG DMA failed for command 0x%04x: %d (sz:%d cord:%d)\n",
			arg->arg.code, ret, max_size, chunk_order);
	return ret;
}

static int
nfp_nsp_command_buf_dma(struct nfp_nsp *nsp,
			struct nfp_nsp_command_buf_arg *arg,
			unsigned int max_size, unsigned int dma_order)
{
	unsigned int chunk_order, buf_order;
	struct nfp_cpp *cpp = nsp->cpp;
	bool sg_ok;
	u64 reg;
	int err;

	buf_order = order_base_2(roundup_pow_of_two(max_size));

	err = nfp_cpp_readq(cpp, nfp_resource_cpp_id(nsp->res),
			    nfp_resource_address(nsp->res) + NFP_CAP_CMD_DMA_SG,
			    &reg);
	if (err < 0)
		return err;
	sg_ok = reg & BIT_ULL(arg->arg.code - 1);

	if (!sg_ok) {
		if (buf_order > dma_order) {
			nfp_err(cpp, "NSP: can't service non-SG DMA for command 0x%04x\n",
				arg->arg.code);
			return -ENOMEM;
		}
		chunk_order = buf_order;
	} else {
		chunk_order = min_t(unsigned int, dma_order, PAGE_SHIFT);
	}

	return nfp_nsp_command_buf_dma_sg(nsp, arg, max_size, chunk_order,
					  dma_order);
}

static int
nfp_nsp_command_buf(struct nfp_nsp *nsp, struct nfp_nsp_command_buf_arg *arg)
{
	unsigned int dma_order, def_size, max_size;
	struct nfp_cpp *cpp = nsp->cpp;
	u64 reg;
	int err;

	if (nsp->ver.minor < 13) {
		nfp_err(cpp, "NSP: Code 0x%04x with buffer not supported (ABI %u.%u)\n",
			arg->arg.code, nsp->ver.major, nsp->ver.minor);
		return -EOPNOTSUPP;
	}

	err = nfp_cpp_readq(cpp, nfp_resource_cpp_id(nsp->res),
			    nfp_resource_address(nsp->res) +
			    NSP_DFLT_BUFFER_CONFIG,
			    &reg);
	if (err < 0)
		return err;

	/* Zero out undefined part of the out buffer */
	if (arg->out_buf && arg->out_size && arg->out_size > arg->in_size)
		memset(arg->out_buf, 0, arg->out_size - arg->in_size);

	max_size = max(arg->in_size, arg->out_size);
	def_size = FIELD_GET(NSP_DFLT_BUFFER_SIZE_MB, reg) * SZ_1M +
		   FIELD_GET(NSP_DFLT_BUFFER_SIZE_4KB, reg) * SZ_4K;
	dma_order = FIELD_GET(NSP_DFLT_BUFFER_DMA_CHUNK_ORDER, reg);
	if (def_size >= max_size) {
		return nfp_nsp_command_buf_def(nsp, arg);
	} else if (!dma_order) {
		nfp_err(cpp, "NSP: default buffer too small for command 0x%04x (%u < %u)\n",
			arg->arg.code, def_size, max_size);
		return -EINVAL;
	}

	return nfp_nsp_command_buf_dma(nsp, arg, max_size, dma_order);
}

int nfp_nsp_wait(struct nfp_nsp *state)
{
	const unsigned long wait_until = jiffies + 30 * HZ;
	int err;

	nfp_dbg(state->cpp, "Waiting for NSP to respond (30 sec max).\n");

	for (;;) {
		const unsigned long start_time = jiffies;

		err = nfp_nsp_command(state, SPCODE_NOOP, 0, 0, 0);
		if (err != -EAGAIN)
			break;

		if (msleep_interruptible(25)) {
			err = -ERESTARTSYS;
			break;
		}

		if (time_after(start_time, wait_until)) {
			err = -ETIMEDOUT;
			break;
		}
	}
	if (err)
		nfp_err(state->cpp, "NSP failed to respond %d\n", err);

	return err;
}

int nfp_nsp_device_soft_reset(struct nfp_nsp *state)
{
	return nfp_nsp_command(state, SPCODE_SOFT_RESET, 0, 0, 0);
}

int nfp_nsp_load_fw(struct nfp_nsp *state, const struct firmware *fw)
{
	return nfp_nsp_command_buf(state, SPCODE_FW_LOAD, fw->size, fw->data,
				   fw->size, NULL, 0);
}

int nfp_nsp_read_eth_table(struct nfp_nsp *state, void *buf, unsigned int size)
{
	return nfp_nsp_command_buf(state, SPCODE_ETH_RESCAN, size, NULL, 0,
				   buf, size);
}

int nfp_nsp_write_eth_table(struct nfp_nsp *state,
			    const void *buf, unsigned int size)
{
	return nfp_nsp_command_buf(state, SPCODE_ETH_CONTROL, size, buf, size,
				   NULL, 0);
}

int nfp_nsp_read_identify(struct nfp_nsp *state, void *buf, unsigned int size)
{
	return nfp_nsp_command_buf(state, SPCODE_NSP_IDENTIFY, size, NULL, 0,
				   buf, size);
}

int nfp_nsp_read_sensors(struct nfp_nsp *state, unsigned int sensor_mask,
			 void *buf, unsigned int size)
{
	return nfp_nsp_command_buf(state, SPCODE_NSP_SENSORS, sensor_mask,
				   NULL, 0, buf, size);
}
