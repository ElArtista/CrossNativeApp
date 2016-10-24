#=- droid.mk -=#
#---------------------------------------------------------------
# Android vars
#---------------------------------------------------------------
AVAILABLE_SDKS   := $(sort $(notdir $(patsubst %/, %, $(basename $(wildcard $(ANDROID_HOME)/platforms/*/)))))
BUILD_SDK        ?= $(lastword $(AVAILABLE_SDKS))
ANDROID_JAR      := $(ANDROID_HOME)/platforms/$(BUILD_SDK)/android.jar
DROID_PLAT_ROOT  := $(dir $(firstword $(MAKEFILE_LIST)))droid
DROIDJSRCDIR     := $(DROID_PLAT_ROOT)/src
DROIDRESDIR      := $(DROID_PLAT_ROOT)/res
ANDROID_MANIFEST := $(DROID_PLAT_ROOT)/AndroidManifest.xml
PACKAGE          := $(shell sed -n -e "s/^\s*package=\"\(.*\)\"\s*/\1/p" $(ANDROID_MANIFEST))
PACKAGE_PATH     := $(subst .,/,$(PACKAGE))

# Base Makefile cross compile params
CROSS_COMPILE := arm-linux-androideabi
SYSROOT := $(NDK_HOME)/platforms/$(BUILD_SDK)/arch-arm

# Include base Makefile
include $(CURDIR)/Makefile

# C flags
CFLAGS   := $(CFLAGS) -fPIC
LDFLAGS  := $(LDFLAGS) -shared

#---------------------------------------------------------------
# Outputs
#---------------------------------------------------------------
DROIDBLDDIR := $(BUILDDIR)/droid
GENDIR      := $(DROIDBLDDIR)/gen
CLAZZDIR    := $(DROIDBLDDIR)/clazz
APK_OUTPUT  := $(DROIDBLDDIR)/build.apk
APK_COPY_D  := $(DROIDBLDDIR)/apkexpload
APK_ALIGNED := $(basename $(APK_OUTPUT))-aligned.apk
DEX_OUTPUT  := $(APK_COPY_D)/classes.dex
SO_OUTPUT   := $(APK_COPY_D)/lib/armeabi/libdatcore.so
KEYSTORE    := $(DROIDBLDDIR)/debug.keystore

#---------------------------------------------------------------
# Rules
#---------------------------------------------------------------
# Java source list, includes generated R.java
JAVA_SRCS := $(strip $(call rwildcard, $(DROIDJSRCDIR), *.java)) $(GENDIR)/$(PACKAGE_PATH)/R.java

# Step that generates R.java
droidgen:
	$(info $(LRED_COLOR)[+] Generating$(NO_COLOR) $(LYELLOW_COLOR)sources...$(NO_COLOR))
	@$(call mkdir, $(GENDIR))
	@aapt package -m -J $(GENDIR) -M $(ANDROID_MANIFEST) -S $(DROIDRESDIR) -I $(ANDROID_JAR)

# Step that builds all android java sources
droidjbld: droidgen
	$(info $(LGREEN_COLOR)[+] Compiling$(NO_COLOR) $(LYELLOW_COLOR)java sources...$(NO_COLOR))
	@$(call mkdir, $(CLAZZDIR))
	@javac -source 1.7 -target 1.7 -Xlint:-options -sourcepath $(GENDIR) -cp $(ANDROID_JAR) -d $(CLAZZDIR) $(JAVA_SRCS)

# Step that merges all java class files into a single dex file
$(DEX_OUTPUT): droidjbld
	$(info $(DCYAN_COLOR)[+] Creating$(NO_COLOR) $(DYELLOW_COLOR)dex file...$(NO_COLOR))
	@$(call mkdir, $(@D))
	@dx --dex --output=$@ $(CLAZZDIR)

# Copies native library to output folder
$(SO_OUTPUT): build
	@$(call mkdir, $(@D))
	@cp $(MASTEROUT_.) $(SO_OUTPUT)

# Constructs apk
APK_ABSPATH := $(abspath $(APK_OUTPUT))
$(APK_OUTPUT): $(SO_OUTPUT) $(DEX_OUTPUT)
	$(info $(DCYAN_COLOR)[+] Creating$(NO_COLOR) $(DYELLOW_COLOR)apk file...$(NO_COLOR))
	@aapt package -f -M $(ANDROID_MANIFEST) -S $(DROIDRESDIR) -I $(ANDROID_JAR) -F $(APK_OUTPUT)
	@$(foreach f, $(DEX_OUTPUT) $(SO_OUTPUT),\
		cd $(APK_COPY_D) && aapt add -f $(APK_ABSPATH) $(subst $(APK_COPY_D)/,,$(f))$(suppress_out)${\n})

# Creates signing keystore
$(KEYSTORE):
	$(info $(LRED_COLOR)[+] Generating$(NO_COLOR) $(LYELLOW_COLOR)keystore...$(NO_COLOR))
	@$(call mkdir, $(@D))
	@keytool -genkey -keystore $(KEYSTORE) \
			-dname "CN=Android Debug,O=Android,C=US" \
			-storepass android -alias androiddebugkey \
			-keypass android -keyalg RSA -keysize 2048 -validity 10000

# Signs apk with keystore
droidsign: $(APK_OUTPUT) $(KEYSTORE)
	$(info $(DCYAN_COLOR)[+] Signing$(NO_COLOR) $(DYELLOW_COLOR)apk with keystore...$(NO_COLOR))
	@jarsigner -sigalg SHA1withRSA -digestalg SHA1 \
			  -keystore $(KEYSTORE) -storepass android $(APK_OUTPUT) androiddebugkey $(suppress_out)

# Aligns into final apk
$(APK_ALIGNED): droidsign
	$(info $(DCYAN_COLOR)[+] Aligning$(NO_COLOR) $(DYELLOW_COLOR)apk...$(NO_COLOR))
	@zipalign -f 4 $(APK_OUTPUT) $@

# Guard for needed environment variables
droidenvvars:
ifndef NDK_HOME
	$(error Environment variable NDK_HOME is not set!)
endif
ifndef ANDROID_HOME
	$(error Environment variable ANDROID_HOME is not set!)
endif

# Useful current build info
droidinfo:
	$(info -------------------------------------------------)
	$(info - Available Sdks: $(AVAILABLE_SDKS))
	$(info - Used Build Sdk: $(BUILD_SDK))
	$(info - Project package: $(PACKAGE))
	$(info -------------------------------------------------)

# Entrypoint
droidbuild: droidenvvars droidinfo $(APK_ALIGNED)

# Install
droidinstall: droidbuild
	$(info $(LRED_COLOR)[+] Installing$(NO_COLOR) $(LYELLOW_COLOR)apk file...$(NO_COLOR))
	@adb uninstall -k $(PACKAGE) $(suppress_out)
	@adb install -r $(APK_ALIGNED) $(suppress_out)

# Set the default goal to main android build rule
.DEFAULT_GOAL := droidbuild
# Non file targets
.PHONY += droidgen droidjbld droidsign droidbuild
