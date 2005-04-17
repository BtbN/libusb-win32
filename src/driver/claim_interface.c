/* LIBUSB-WIN32, Generic Windows USB Library
 * Copyright (c) 2002-2005 Stephan Meyer <ste_meyer@web.de>
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



#include "libusb_driver.h"



NTSTATUS claim_interface(libusb_device_extension *device_extension,
                         int interface)
{
  DEBUG_MESSAGE("claim_interface(): interface %d", interface);

  if(interface >= LIBUSB_MAX_NUMBER_OF_INTERFACES)
    {
      DEBUG_ERROR("claim_interface(): invalid interface %d", interface);
      return STATUS_INVALID_PARAMETER;
    }

  if(!device_extension->interfaces[interface].valid)
    {
      DEBUG_ERROR("claim_interface(): invalid interface %d", interface);
      return STATUS_INVALID_PARAMETER;
    }

  if(device_extension->interfaces[interface].claimed)
    {
      DEBUG_ERROR("claim_interface(): could not claim interface %d, "
                  "interface is already claimed", interface);
      return STATUS_DEVICE_BUSY;
    }

  device_extension->interfaces[interface].claimed = TRUE;

  return STATUS_SUCCESS;
}
