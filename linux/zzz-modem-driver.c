/*
 * Copyright (C) 2018 Markus Lavin (https://www.zzzconsulting.se/)
 *
 * All rights reserved.
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <https://www.gnu.org/licenses/>.
 *
 */

#include <linux/init.h>
#include <linux/interrupt.h>
#include <linux/irqdomain.h>
#include <linux/module.h>
#include <linux/kernel.h>
#include <linux/platform_device.h>
#include <linux/of_address.h>
#include <linux/of_irq.h>
#include <linux/device.h>
#include <linux/fs.h>
#include <linux/uaccess.h>

#define DEVICE_NAME "zzz-modem"
#define CLASS_NAME "zzz-modem"

MODULE_LICENSE("GPL");
MODULE_AUTHOR("Markus Lavin (https://www.zzzconsulting.se)");
MODULE_DESCRIPTION("Device driver for zzz-modem");
MODULE_VERSION("0.1");

static const uint32_t tx_buf_addr = 0x000;
static const uint32_t tx_buf_size = 0x400;
static const uint32_t rx_buf_addr = 0x400;
static const uint32_t rx_buf_size = 0x400;

static const uint32_t tx_rp_addr = 0x800;
static const uint32_t tx_wp_addr = 0x804;
static const uint32_t rx_rp_addr = 0x808;
static const uint32_t rx_wp_addr = 0x80c;

/*
	tx_rp == tx_wp => buffer is empty

	tx_rp <= tx_wp : free space is buffer_size - (tx_wp - tx_rp) - 1
	tx_rp >  tx_wp : free space is tx_rp - tx_wp - 1
*/


static wait_queue_head_t read_wq;
static wait_queue_head_t write_wq;

static void __iomem *io_base = NULL;
static int irq_num;

static int majorNumber;
static struct class *zzzClass  = NULL;
static struct device *zzzDevice = NULL;

static int dev_open(struct inode *, struct file *);
static int dev_release(struct inode *, struct file *);
static ssize_t dev_read(struct file *, char *, size_t, loff_t *);
static ssize_t dev_write(struct file *, const char *, size_t, loff_t *);

static struct file_operations fops =
{
	.open = dev_open,
	.read = dev_read,
	.write = dev_write,
	.release = dev_release,
};

static irq_handler_t zzz_irq_handler(unsigned int irq, void *dev_id, struct pt_regs *regs)
{
	wake_up_interruptible(&read_wq);
	wake_up_interruptible(&write_wq);

	return (irq_handler_t)IRQ_HANDLED;
}

static int __zzz_driver_probe(struct platform_device *pdev)
{
	struct device *dev = &pdev->dev;
	struct device_node *np = dev->of_node;
	struct resource res;
	int ret;

	init_waitqueue_head(&read_wq);
	init_waitqueue_head(&write_wq);

	irq_num = irq_of_parse_and_map(np, 0);

	dev_info(dev, "probe: irq_num=%d\n", irq_num);

	if ((ret = request_irq(irq_num, (irq_handler_t) zzz_irq_handler, IRQF_TRIGGER_RISING, DEVICE_NAME, dev))) {
		dev_err(dev, "probe: request_irq: %d\n", ret);
		return ret;
	}

	if ((ret = of_address_to_resource(np, 0, &res))) {
		dev_err(dev, "probe: of_address_to_resource: %d\n", ret);
		return ret;
	}

	io_base = ioremap(res.start, resource_size(&res));

	majorNumber = register_chrdev(0, DEVICE_NAME, &fops);
	if (majorNumber < 0){
		return majorNumber;
	}

	zzzClass = class_create(THIS_MODULE, CLASS_NAME);
	if (IS_ERR(zzzClass)){
		unregister_chrdev(majorNumber, DEVICE_NAME);
		return PTR_ERR(zzzClass);
	}

	zzzDevice = device_create(zzzClass, NULL, MKDEV(majorNumber, 0), NULL, DEVICE_NAME);
	if (IS_ERR(zzzDevice)){
		class_destroy(zzzClass);
		unregister_chrdev(majorNumber, DEVICE_NAME);
		return PTR_ERR(zzzDevice);
	}

	return 0;
}

static int __zzz_driver_remove(struct platform_device *pdev)
{
	device_destroy(zzzClass, MKDEV(majorNumber, 0));
	class_destroy(zzzClass);
	unregister_chrdev(majorNumber, DEVICE_NAME);

	free_irq(irq_num, &pdev->dev);
	irq_dispose_mapping(irq_num);

	return 0;
}

static int dev_open(struct inode *inodep, struct file *filep)
{
	return 0;
}

static ssize_t dev_read(struct file *filep, char *buffer, size_t len, loff_t *offset)
{
	uint32_t rp, wp;

	DEFINE_WAIT(wait);

	rp = readl(io_base + rx_rp_addr);
	wp = readl(io_base + rx_wp_addr);

	while (rp == wp) {
		prepare_to_wait(&read_wq, &wait, TASK_INTERRUPTIBLE);
		schedule();
		finish_wait(&read_wq, &wait);

		rp = readl(io_base + rx_rp_addr);
		wp = readl(io_base + rx_wp_addr);
	}

	{
		uint32_t msg_byte_len = readl(io_base + rx_buf_addr + rp);
		uint32_t msg_word_len = (msg_byte_len + 3) >> 2;
		int i;

		rp = (rp + 4) & (rx_buf_size - 1);

		for (i = 0; i < msg_word_len; i++) {
			uint32_t tmp32;
			tmp32 = readl(io_base + rx_buf_addr + rp);
			put_user(tmp32, (__user uint32_t *)(buffer + (i << 2)));
			rp = (rp + 4) & (rx_buf_size - 1);
		}

		writel(rp, io_base + rx_rp_addr);

		return msg_byte_len;
	}
}

static ssize_t dev_write(struct file *filep, const char *buffer, size_t len, loff_t *offset)
{
	uint32_t rp, wp;
	uint32_t free_bytes;
	uint32_t word_len;
	uint32_t tail;

	DEFINE_WAIT(wait);

	rp = readl(io_base + tx_rp_addr);
	wp = readl(io_base + tx_wp_addr);
	free_bytes = (rp <= wp) ?  tx_buf_size - (wp - rp) - 4 : (rp - wp) - 4;

	while (free_bytes < len + 4 /* header */) {
		prepare_to_wait(&write_wq, &wait, TASK_INTERRUPTIBLE);
		schedule();
		finish_wait(&write_wq, &wait);

		rp = readl(io_base + rx_rp_addr);
		wp = readl(io_base + rx_wp_addr);
		free_bytes = (rp <= wp) ?  tx_buf_size - (wp - rp) - 4 : (rp - wp) - 4;
	}

	{
		int i;

		/* First write the header */
		writel(len, io_base + tx_buf_addr + wp);
		wp = (wp + 4) & (tx_buf_size - 1);

		/* Then write the payload */
		word_len = (len >> 2);

		/* Complete words */
		for (i = 0; i < word_len; i++) {
			uint32_t tmp;
			get_user(tmp, (__user uint32_t *)(buffer + (i << 2)));
			writel(tmp, io_base + tx_buf_addr + wp);
			wp = (wp + 4) & (tx_buf_size - 1);
		}

		/* Handle tail */
		tail = len - (word_len << 2);
		if (tail > 0) {
			uint32_t tmp32 = 0;

			for (i = 0; i < tail; i++) {
				uint8_t tmp8;
				get_user(tmp8, buffer + (word_len << 2) + i);
				tmp32 |= (tmp8 << (i * 8));
			}

			writel(tmp32, io_base + tx_buf_addr + wp);
			wp = (wp + 4) & (tx_buf_size - 1);
		}

		/* Finally commit the updated wp */
		writel(wp, io_base + tx_wp_addr);
	}

	return len;
}

static int dev_release(struct inode *inodep, struct file *filep)
{
	return 0;
}

static const struct of_device_id __zzz_driver_id[] = {
	{.compatible = DEVICE_NAME},
	{}
};

static struct platform_driver __zzz_driver = {
	.driver = {
		.name = DEVICE_NAME,
		.owner = THIS_MODULE,
		.of_match_table = of_match_ptr(__zzz_driver_id),
	},
	.probe = __zzz_driver_probe,
	.remove = __zzz_driver_remove
};

module_platform_driver(__zzz_driver);
