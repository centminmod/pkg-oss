# Shared Centmin Mod compiler/optimization flags — injected verbatim at
# spec-generation time into nginx.spec.in AND nginx-module.spec.in via the
# COMPILER_FLAGS placeholder (see the sed rules in rpm/SPECS/Makefile).
# CC_OPT and every *_CC_OPT/*_LD_OPT here must be identical across base and
# module builds for ABI compatibility. WITH_LD_OPT is intentionally NOT shared:
# the base binary links with -pie, modules build .so files and must not —
# each template defines its own WITH_LD_OPT next to its placeholder.
#
# %%{optflags} intentionally NOT used because it reflects system GCC defaults,
# not the gcc-toolset compiler. Dropping %%{optflags} loses Red Hat's -specs=
# annotations but gains explicit control matching CM's build configuration.
%if 0%{?rhel} >= 10
%define WITH_CC_OPT -O3 -g -fPIC -fstack-protector-strong -fstack-clash-protection -Wimplicit-fallthrough=0 -Wformat -Wformat-security -Wp,-U_FORTIFY_SOURCE,-D_FORTIFY_SOURCE=3 --param=ssp-buffer-size=4 $(pcre2-config --cflags)
%else
%define WITH_CC_OPT -O3 -g -fPIC -fstack-protector-strong -fstack-clash-protection -Wimplicit-fallthrough=0 -Wformat -Wformat-security -Wp,-D_FORTIFY_SOURCE=2 --param=ssp-buffer-size=4 $(pcre2-config --cflags)
%endif

# LTO support — -flto=auto on both compile and link lines (GCC requirement)
%if "%{opt_lto}" == "y"
%define LTO_CC_OPT -flto=auto
%define LTO_LD_OPT -flto=auto
%else
%define LTO_CC_OPT %{nil}
%define LTO_LD_OPT %{nil}
%endif

# Microarchitecture targeting — compile-time only
%if "%{opt_march}" == "x86-64-v2"
%define MARCH_CC_OPT -march=x86-64-v2
%endif
%if "%{opt_march}" == "x86-64-v3"
%define MARCH_CC_OPT -march=x86-64-v3
%endif
%if "%{opt_march}" == "x86-64-v4"
%define MARCH_CC_OPT -march=x86-64-v4
%endif
%if "%{opt_march}" == "generic"
%define MARCH_CC_OPT %{nil}
%endif

# Mold linker — link-time only (BuildRequires: mold is declared per-template)
%if "%{opt_linker}" == "mold"
%define LINKER_LD_OPT -fuse-ld=mold
%else
%define LINKER_LD_OPT %{nil}
%endif

# AutoFDO — compile-time profile-guided optimization
# -fauto-profile goes in --with-cc-opt ONLY (compile-time flag, not linker)
# -Wno-error=array-bounds: AutoFDO profile-guided inlining can trigger
# false-positive bounds warnings with -Werror (GCC bug with aggressive optimization)
%if "%{opt_autofdo}" != "none" && "%{opt_autofdo}" != ""
%define AUTOFDO_CC_OPT -fauto-profile=%{opt_autofdo} -Wno-error=array-bounds
%else
%define AUTOFDO_CC_OPT %{nil}
%endif
