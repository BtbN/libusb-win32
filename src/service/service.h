/* LIBUSB-WIN32, Generic Windows USB Driver
 * Copyright (C) 2002-2003 Stephan Meyer, <ste_meyer@web.de>
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 */



#ifndef __USB_SERVICE_H__
#define __USB_SERVICE_H__

#include "registry.h"


#define LIBUSB_SERVICE_NAME   "libusbd"
#define LIBUSB_SERVICE_PATH   "system32\\libusbd-nt.exe"


bool_t usb_service_load_dll();
bool_t usb_service_free_dll();


void usb_service_start_filter(void);
void usb_service_stop_filter(int all);


bool_t usb_create_service(const char *name, const char *display_name,
			  const char *binary_path, unsigned long type,
			  unsigned long start_type);
bool_t usb_delete_service(const char *name);
bool_t usb_start_service(const char *name);
bool_t usb_stop_service(const char *name);
bool_t usb_service_reboot_required(void);


#endif
