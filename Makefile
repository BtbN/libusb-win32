

CC = gcc
LD = ld
MAKE = make
CP = cp -a
CD = cd
MV = mv
RM = -rm -fr
TAR = tar
WINDRES = windres
NSIS = makensis
INSTALL = install

VERSION_MAJOR = 0
VERSION_MINOR = 1
VERSION_MICRO = 8
VERSION_NANO = 1

VERSION = $(VERSION_MAJOR).$(VERSION_MINOR).$(VERSION_MICRO).$(VERSION_NANO)
RC_VERSION = $(VERSION_MAJOR),$(VERSION_MINOR),$(VERSION_MICRO),$(VERSION_NANO)
INF_VERSION = $(shell date +"%m\/%d\/%Y"), $(VERSION)
DATE = $(shell date +"%Y%m%d")

TARGET = libusb
DLL_TARGET = $(TARGET)$(VERSION_MAJOR)
LIB_TARGET = $(TARGET)
DRIVER_TARGET = $(TARGET)0.sys
INSTALLER_TARGET = libusb-win32-filter-bin-$(VERSION).exe

INSTALL_DIR = /usr
OBJECTS = usb.o error.o descriptors.o windows.o resource.o install.o \
	registry.o service.o win_debug.o

DRIVER_OBJECTS = abort_endpoint.o claim_interface.o clear_feature.o \
	debug.o dispatch.o driver_registry.o get_configuration.o \
	get_descriptor.o get_interface.o get_status.o internal_ioctl.o \
	ioctl.o libusb_driver.o pnp.o release_interface.o reset_device.o \
	reset_endpoint.o set_configuration.o set_descriptor.o \
	set_feature.o set_interface.o transfer.o vendor_request.o \
	power.o libusb_driver_rc.o 


SRC_DIST_DIR = $(TARGET)-win32-src-$(VERSION)
BIN_DIST_DIR = $(TARGET)-win32-device-bin-$(VERSION)


DIST_SOURCE_FILES = ./src
DIST_MISC_FILES = COPYING_LGPL.txt COPYING_GPL.txt AUTHORS.txt ChangeLog.txt 

SRC_DIR = ./src
DRIVER_SRC_DIR = $(SRC_DIR)/driver

VPATH = .:./src:./src/driver:./tests:./src/service

INCLUDES = -I./src -I./src/driver -I./src/service

CFLAGS = -O2 -Wall -mno-cygwin

CPPFLAGS = -DVERSION_MAJOR=$(VERSION_MAJOR) \
	-DVERSION_MINOR=$(VERSION_MINOR) \
	-DVERSION_MICRO=$(VERSION_MICRO) \
	-DVERSION_NANO=$(VERSION_NANO) -DDBG

LDFLAGS = -s -mwindows -mno-cygwin -L. -lusb -lgdi32 -luser32 -lsetupapi \
	 -lcfgmgr32

DLL_LDFLAGS = -s -mwindows -shared -mno-cygwin \
	-Wl,--output-def,$(DLL_TARGET).def \
	-Wl,--out-implib,$(LIB_TARGET).a \
	-Wl,--kill-at \
	-L. -lsetupapi -lnewdev -lcfgmgr32


DRIVER_LDFLAGS =  -s -shared -Wl,--entry,_DriverEntry@8 \
	-nostartfiles -nostdlib -L. -lusbd -lntoskrnl


TEST_FILES = testlibusb.exe testlibusb-win.exe


ifndef DDK_ROOT_PATH
	DDK_ROOT_PATH = C:/WINDDK
endif

.PHONY: all
all: $(DLL_TARGET).dll $(TEST_FILES) $(DRIVER_TARGET) \
	libusbd-9x.exe libusbd-nt.exe $(TARGET).inf README.txt
	unix2dos *.txt *.inf

$(DLL_TARGET).dll: driver_api.h $(OBJECTS)
	dlltool --dllname newdev.dll --def ./src/newdev.def \
	--output-lib libnewdev.a
	$(CC) -o $@ $(OBJECTS) $(DLL_LDFLAGS) 

%.o: %.c
	$(CC) -c $< -o $@ $(CFLAGS) -Wall $(CPPFLAGS) $(INCLUDES) 

testlibusb.exe: testlibusb.o
	$(CC) $(CFLAGS) -o $@ -I./src  $^ $(LDFLAGS)

testlibusb-win.exe: testlibusb_win.o
	$(CC) $(CFLAGS) -o $@ -I./src  $^ $(LDFLAGS)

libusbd-nt.exe: service_nt.o service.o registry.o resource.o win_debug.o
	$(CC) $(CPPFLAGS) -Wall $(CFLAGS) -o $@ $^ $(LDFLAGS)

libusbd-9x.exe: service_9x.o service.o registry.o resource.o win_debug.o
	$(CC) $(CPPFLAGS) -Wall $(CFLAGS) -o $@ $^ $(LDFLAGS)

README.txt: README.in
	sed -e 's/@VERSION@/$(VERSION)/' $< > $@

%.o: %.rc.in
	sed -e 's/@RC_VERSION@/$(RC_VERSION)/' \
	-e 's/@VERSION@/$(VERSION)/' $< | $(WINDRES) -o $@

%.rc: %.rc.in
	sed -e 's/@RC_VERSION@/$(RC_VERSION)/' \
	-e 's/@VERSION@/$(VERSION)/' $< > $(^D)/$@

%.h: %.h.in
	sed -e 's/@VERSION_MAJOR@/$(VERSION_MAJOR)/' \
	-e 's/@VERSION_MINOR@/$(VERSION_MINOR)/' \
	-e 's/@VERSION_MICRO@/$(VERSION_MICRO)/' \
	-e 's/@VERSION_NANO@/$(VERSION_NANO)/' \
	$< > $(^D)/$@

%.inf: %.inf.in
	sed -e 's/@INF_VERSION@/$(INF_VERSION)/' $< > $@

$(DRIVER_TARGET): $(TARGET)_driver.rc driver_api.h $(DRIVER_OBJECTS)
	dlltool --dllname usbd.sys --def ./src/driver/usbd.def \
	--output-lib libusbd.a
	$(CC) -o $@ $(DRIVER_OBJECTS) $(DRIVER_LDFLAGS)

.PHONY: bcc_implib
bcc_lib:
	implib -a $(LIB_TARGET).lib $(DLL_TARGET).dll

.PHONY: msvc_lib
msvc_lib:
	$(DDK_ROOT_PATH)/bin/x86/lib.exe /machine:i386 /def:$(DLL_TARGET).def 
	$(MV) $(DLL_TARGET).lib $(LIB_TARGET).lib

.PHONY: bin_dist
bin_dist: all
	$(INSTALL) -d $(BIN_DIST_DIR)/lib/gcc
	$(INSTALL) -d $(BIN_DIST_DIR)/lib/bcc
	$(INSTALL) -d $(BIN_DIST_DIR)/lib/msvc
	$(INSTALL) -d $(BIN_DIST_DIR)/include
	$(INSTALL) -d $(BIN_DIST_DIR)/bin
	$(INSTALL) $(TEST_FILES) $(BIN_DIST_DIR)/bin
	$(INSTALL) *.manifest $(BIN_DIST_DIR)/bin

	$(INSTALL) $(DRIVER_TARGET) $(BIN_DIST_DIR)/bin
	$(INSTALL) $(TARGET).inf $(BIN_DIST_DIR)/bin
	$(INSTALL) $(DLL_TARGET).dll $(BIN_DIST_DIR)/bin

	$(INSTALL) $(SRC_DIR)/usb.h $(BIN_DIST_DIR)/include
	$(INSTALL) $(LIB_TARGET).a $(BIN_DIST_DIR)/lib/gcc
	$(MAKE) bcc_lib 
	$(INSTALL) $(LIB_TARGET).lib $(BIN_DIST_DIR)/lib/bcc
	$(MAKE) msvc_lib
	$(INSTALL) $(LIB_TARGET).lib $(BIN_DIST_DIR)/lib/msvc
	$(INSTALL) $(DIST_MISC_FILES) README.txt $(BIN_DIST_DIR)


.PHONY: src_dist
src_dist:
	$(INSTALL) -d $(SRC_DIST_DIR)/src
	$(INSTALL) -d $(SRC_DIST_DIR)/src/service
	$(INSTALL) -d $(SRC_DIST_DIR)/src/driver
	$(INSTALL) -d $(SRC_DIST_DIR)/tests

	$(INSTALL) $(SRC_DIR)/*.c $(SRC_DIST_DIR)/src
	$(INSTALL) $(SRC_DIR)/*.h $(SRC_DIST_DIR)/src
	$(INSTALL) $(SRC_DIR)/*.rc.in $(SRC_DIST_DIR)/src
	$(INSTALL) ./tests/*.c $(SRC_DIST_DIR)/tests

	$(INSTALL) $(SRC_DIR)/service/*.c $(SRC_DIST_DIR)/src/service
	$(INSTALL) $(SRC_DIR)/service/*.h $(SRC_DIST_DIR)/src/service

	$(INSTALL) $(DRIVER_SRC_DIR)/usbd.lib $(SRC_DIST_DIR)/src/driver
	$(INSTALL) $(DRIVER_SRC_DIR)/*.h $(SRC_DIST_DIR)/src/driver
	$(INSTALL) $(DRIVER_SRC_DIR)/*.c $(SRC_DIST_DIR)/src/driver
	$(INSTALL) $(DRIVER_SRC_DIR)/*.in $(SRC_DIST_DIR)/src/driver
	$(INSTALL) $(DRIVER_SRC_DIR)/sources $(SRC_DIST_DIR)/src/driver
	$(INSTALL) $(DRIVER_SRC_DIR)/makefile $(SRC_DIST_DIR)/src/driver

	$(INSTALL) $(DIST_MISC_FILES) *.in Makefile *.bat *.sh *.manifest \
		license_nsis.txt $(SRC_DIST_DIR)


.PHONY: dist
dist: bin_dist src_dist
	sed -e 's/@VERSION@/$(VERSION)/' \
	-e 's/@BIN_DIST_DIR@/$(BIN_DIST_DIR)/' \
	-e 's/@SRC_DIST_DIR@/$(SRC_DIST_DIR)/' \
	-e 's/@INSTALLER_TARGET@/$(INSTALLER_TARGET)/' \
	install.nsi.in > install.nsi
	$(TAR) -czf $(SRC_DIST_DIR).tar.gz $(SRC_DIST_DIR) 
	$(TAR) -czf $(BIN_DIST_DIR).tar.gz $(BIN_DIST_DIR)
	$(NSIS) install.nsi
	$(RM) $(SRC_DIST_DIR)
	$(RM) $(BIN_DIST_DIR)

.PHONY: snapshot
snapshot: VERSION = $(DATE)
snapshot: dist

.PHONY: clean
clean:	
	$(RM) *.o *.dll *.a *.exp *.lib *.exe *.tar.gz *.inf *~ *.nsi
	$(RM) ./src/*~ *.sys *.log
	$(RM) $(SRC_DIR)/*.rc
	$(RM) $(SRC_DIR)/drivers/*.log $(SRC_DIR)/driver/i386
	$(RM) $(DRIVER_SRC_DIR)/*~ $(DRIVER_SRC_DIR)/*.rc
	$(RM) $(DRIVER_SRC_DIR)/*.log
	$(RM) $(DRIVER_SRC_DIR)/*_wxp_x86
	$(RM) $(DRIVER_SRC_DIR)/driver_api.h
	$(RM) README.txt

