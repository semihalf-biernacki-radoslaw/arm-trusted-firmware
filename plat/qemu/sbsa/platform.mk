#
# Copyright (c) 2018, ARM Limited and Contributors. All rights reserved.
#
# SPDX-License-Identifier: BSD-3-Clause
#

# Use the GICv3 driver on QEMU by default
QEMU_USE_GIC_DRIVER	:= QEMU_GICV3

ifeq (${SPD},opteed)
add-lib-optee 		:= 	yes
endif

include lib/libfdt/libfdt.mk

# Enable new version of image loading on QEMU platforms
LOAD_IMAGE_V2		:=	1

ifeq ($(NEED_BL32),yes)
$(eval $(call add_define,QEMU_LOAD_BL32))
endif

PLAT_QEMU_PATH               :=      plat/qemu/sbsa
PLAT_QEMU_COMMON_PATH        :=      plat/qemu/common
PLAT_INCLUDES		:=	-Iinclude/plat/arm/common/		\
				-I${PLAT_QEMU_COMMON_PATH}/include			\
				-I${PLAT_QEMU_PATH}/include			\
				-Iinclude/common/tbbr

PLAT_INCLUDES		+=	-Iinclude/plat/arm/common/${ARCH}

# Use translation tables library v2 by default
ARM_XLAT_TABLES_LIB_V1		:=	0
$(eval $(call assert_boolean,ARM_XLAT_TABLES_LIB_V1))
$(eval $(call add_define,ARM_XLAT_TABLES_LIB_V1))


PLAT_BL_COMMON_SOURCES	:=	${PLAT_QEMU_COMMON_PATH}/qemu_common.c			\
				${PLAT_QEMU_COMMON_PATH}/qemu_console.c		  \
				drivers/arm/pl011/${ARCH}/pl011_console.S

ifeq (${ARM_XLAT_TABLES_LIB_V1}, 1)
PLAT_BL_COMMON_SOURCES	+=	lib/xlat_tables/xlat_tables_common.c		\
				lib/xlat_tables/${ARCH}/xlat_tables.c
else
include lib/xlat_tables_v2/xlat_tables.mk

PLAT_BL_COMMON_SOURCES	+=	${XLAT_TABLES_LIB_SRCS}
endif

ifneq (${TRUSTED_BOARD_BOOT},0)

    include drivers/auth/mbedtls/mbedtls_crypto.mk
    include drivers/auth/mbedtls/mbedtls_x509.mk

    USE_TBBR_DEFS	:=	1

    AUTH_SOURCES	:=	drivers/auth/auth_mod.c			\
				drivers/auth/crypto_mod.c		\
				drivers/auth/img_parser_mod.c		\
				drivers/auth/tbbr/tbbr_cot.c

    PLAT_INCLUDES	+=	-Iinclude/bl1/tbbr

    BL1_SOURCES		+=	${AUTH_SOURCES}				\
				bl1/tbbr/tbbr_img_desc.c		\
				plat/common/tbbr/plat_tbbr.c		\
				${PLAT_QEMU_COMMON_PATH}/qemu_trusted_boot.c	     	\
				$(PLAT_QEMU_COMMON_PATH)/qemu_rotpk.S

    BL2_SOURCES		+=	${AUTH_SOURCES}				\
				plat/common/tbbr/plat_tbbr.c		\
				${PLAT_QEMU_COMMON_PATH}/qemu_trusted_boot.c	     	\
				$(PLAT_QEMU_COMMON_PATH)/qemu_rotpk.S

    ROT_KEY             = $(BUILD_PLAT)/rot_key.pem
    ROTPK_HASH          = $(BUILD_PLAT)/rotpk_sha256.bin

    $(eval $(call add_define_val,ROTPK_HASH,'"$(ROTPK_HASH)"'))

    $(BUILD_PLAT)/bl1/qemu_rotpk.o: $(ROTPK_HASH)
    $(BUILD_PLAT)/bl2/qemu_rotpk.o: $(ROTPK_HASH)

    certificates: $(ROT_KEY)

    $(ROT_KEY):
	@echo "  OPENSSL $@"
	$(Q)openssl genrsa 2048 > $@ 2>/dev/null

    $(ROTPK_HASH): $(ROT_KEY)
	@echo "  OPENSSL $@"
	$(Q)openssl rsa -in $< -pubout -outform DER 2>/dev/null |\
	openssl dgst -sha256 -binary > $@ 2>/dev/null
endif

BL1_SOURCES		+=	drivers/io/io_semihosting.c		\
				drivers/io/io_storage.c			\
				drivers/io/io_fip.c			\
				drivers/io/io_memmap.c			\
				lib/semihosting/semihosting.c		\
				lib/semihosting/${ARCH}/semihosting_call.S \
				${PLAT_QEMU_COMMON_PATH}/qemu_io_storage.c		\
				${PLAT_QEMU_COMMON_PATH}/${ARCH}/plat_helpers.S	\
				${PLAT_QEMU_COMMON_PATH}/qemu_bl1_setup.c

BL1_SOURCES		+=	lib/cpus/aarch64/aem_generic.S		\
				lib/cpus/aarch64/cortex_a53.S		\
				lib/cpus/aarch64/cortex_a57.S

BL2_SOURCES		+=	drivers/io/io_semihosting.c		\
				drivers/io/io_storage.c			\
				drivers/io/io_fip.c			\
				drivers/io/io_memmap.c			\
				lib/semihosting/semihosting.c		\
				lib/semihosting/${ARCH}/semihosting_call.S\
				${PLAT_QEMU_COMMON_PATH}/qemu_io_storage.c		\
				${PLAT_QEMU_COMMON_PATH}/${ARCH}/plat_helpers.S	\
				${PLAT_QEMU_COMMON_PATH}/qemu_bl2_setup.c		\
				${PLAT_QEMU_COMMON_PATH}/dt.c				\
				$(LIBFDT_SRCS)
ifeq (${LOAD_IMAGE_V2},1)
BL2_SOURCES		+=	${PLAT_QEMU_COMMON_PATH}/qemu_bl2_mem_params_desc.c	\
				${PLAT_QEMU_COMMON_PATH}/qemu_image_load.c		\
				common/desc_image_load.c
endif
ifeq ($(add-lib-optee),yes)
BL2_SOURCES		+=	lib/optee/optee_utils.c
endif

QEMU_GICV2_SOURCES	:=	drivers/arm/gic/v2/gicv2_helpers.c	\
				drivers/arm/gic/v2/gicv2_main.c		\
				drivers/arm/gic/common/gic_common.c	\
				plat/common/plat_gicv2.c		\
				${PLAT_QEMU_COMMON_PATH}/qemu_gicv2.c

QEMU_GICV3_SOURCES	:=	drivers/arm/gic/v3/gicv3_helpers.c	\
				drivers/arm/gic/v3/gicv3_main.c		\
				drivers/arm/gic/common/gic_common.c	\
				plat/common/plat_gicv3.c		\
				${PLAT_QEMU_COMMON_PATH}/qemu_gicv3.c

ifeq (${QEMU_USE_GIC_DRIVER}, QEMU_GICV2)
QEMU_GIC_SOURCES	:=	${QEMU_GICV2_SOURCES}
else ifeq (${QEMU_USE_GIC_DRIVER}, QEMU_GICV3)
QEMU_GIC_SOURCES	:=	${QEMU_GICV3_SOURCES}
else
$(error "Incorrect GIC driver chosen for QEMU platform")
endif

BL31_SOURCES		+=	lib/cpus/aarch64/aem_generic.S		\
				lib/cpus/aarch64/cortex_a53.S		\
				lib/cpus/aarch64/cortex_a57.S		\
				plat/common/plat_psci_common.c		\
				${PLAT_QEMU_COMMON_PATH}/qemu_pm.c			\
				${PLAT_QEMU_COMMON_PATH}/topology.c			\
				${PLAT_QEMU_COMMON_PATH}/aarch64/plat_helpers.S	\
				${PLAT_QEMU_COMMON_PATH}/qemu_bl31_setup.c		\
				${QEMU_GIC_SOURCES}

# Add the build options to pack Trusted OS Extra1 and Trusted OS Extra2 images
# in the FIP if the platform requires.
ifneq ($(BL32_EXTRA1),)
$(eval $(call TOOL_ADD_IMG,bl32_extra1,--tos-fw-extra1))
endif
ifneq ($(BL32_EXTRA2),)
$(eval $(call TOOL_ADD_IMG,bl32_extra2,--tos-fw-extra2))
endif

SEPARATE_CODE_AND_RODATA := 1
ENABLE_STACK_PROTECTOR	 := 0
ifneq ($(ENABLE_STACK_PROTECTOR), 0)
	PLAT_BL_COMMON_SOURCES += ${PLAT_QEMU_COMMON_PATH}/qemu_stack_protector.c
endif

MULTI_CONSOLE_API	:= 1

# Disable the PSCI platform compatibility layer
ENABLE_PLAT_COMPAT	:= 	0

BL32_RAM_LOCATION	:=	tdram
ifeq (${BL32_RAM_LOCATION}, tsram)
  BL32_RAM_LOCATION_ID = SEC_SRAM_ID
else ifeq (${BL32_RAM_LOCATION}, tdram)
  BL32_RAM_LOCATION_ID = SEC_DRAM_ID
else
  $(error "Unsupported BL32_RAM_LOCATION value")
endif

# Use known base for UEFI if not given from command line
# By default BL33 is at FLASH1 base
PRELOADED_BL33_BASE ?= 0x04000000

# Process flags
$(eval $(call add_define,BL32_RAM_LOCATION_ID))

# Do not enable SVE
ENABLE_SVE_FOR_NS	:=	0
