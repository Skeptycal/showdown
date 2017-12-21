-include local.mk
include mk/compat.mk
include mk/discount.mk
include mk/flatpak.mk
include mk/dist.mk

# Installation directories (may be overridden on the command line)
PREFIX     = /usr/local
BINDIR     = $(PREFIX)/bin
DATADIR    = $(PREFIX)/share
DESKTOPDIR = $(DATADIR)/applications
ICONDIR    = $(DATADIR)/icons/hicolor
APPICONDIR = $(ICONDIR)/scalable/apps

# The following 3 commands are run after the install and uninstall
# targets, unless the DESTDIR variable is set. The presence of DESTDIR
# usually indicates a distro packaging environment, in which case the
# equivalent, distro-provided macros/hooks should be used instead.
define POSTINSTALL
 update-desktop-database -q '$(DESKTOPDIR)' || :
 touch -c '$(ICONDIR)' || :
 gtk-update-icon-cache -qtf '$(ICONDIR)' || :
endef

ifeq "" "$(filter-out install,$(or $(MAKECMDGOALS),all))"
 # Don't run optcheck for "make install"
 OPTCHECK = :
else
 OPTCHECK = mk/optcheck.sh
endif

APPID = org.gnome.Showdown
APPICON = showdown
VERSION = $(shell mk/version.sh 0.5)

VALAC ?= valac
RESCOMPILE ?= glib-compile-resources
INSTALL = install
INSTALL_DIR = $(INSTALL) -d -m755
RM = rm -f

VALAFILES = $(addsuffix .vala, showdown window view version)
VALAPKGS = --pkg gtk+-3.0 --pkg webkit2gtk-4.0 --vapidir . --pkg libmarkdown
CWARNFLAGS = -Wno-incompatible-pointer-types -Wno-discarded-qualifiers

VALAFLAGS = \
    --target-glib=2.48 \
    --gresources=res/resources.xml \
    $(foreach f, $(CWARNFLAGS) $(DISCOUNT_FLAGS),-X '$(f)') \
    $(VALAFLAGS_EXTRA)

RESOURCES = $(addprefix res/, \
    window.ui menus.ui help-overlay.ui \
    template.html error.html \
    main.css toc.css \
    showdown.svg \
)

all: showdown

run: all
	./showdown README.md

showdown: $(VALAFILES) resources.c libmarkdown.vapi
	$(VALAC) $(VALAFLAGS) $(VALAPKGS) -o $@ $(filter %.vala %.c, $^)

resources.c: res/resources.xml $(RESOURCES)
	$(RESCOMPILE) --sourcedir res/ --generate-source --target $@ $<

version.vala: version.vala.in version.txt
	printf "$$(cat version.vala.in)" "$$(cat version.txt)" > $@

version.txt: FORCE
	@$(OPTCHECK) '$(VERSION)' $@

install: all
	$(INSTALL_DIR) '$(DESTDIR)$(BINDIR)' '$(DESTDIR)$(APPICONDIR)'
	$(INSTALL) -m755 showdown '$(DESTDIR)$(BINDIR)/showdown'
	$(INSTALL) -m644 res/showdown.svg '$(DESTDIR)$(APPICONDIR)/$(APPICON).svg'
	desktop-file-install --dir='$(DESTDIR)$(DESKTOPDIR)' \
	  --set-key=Exec --set-value='$(BINDIR)/showdown %U' \
	  --set-icon='$(APPICON)' share/$(APPID).desktop
	$(if $(DESTDIR),, $(POSTINSTALL))

install-home:
	@$(MAKE) all install PREFIX=$(HOME)/.local

uninstall:
	$(RM) '$(DESTDIR)$(BINDIR)/showdown'
	$(RM) '$(DESTDIR)$(APPICONDIR)/showdown.svg'
	$(RM) '$(DESTDIR)$(DESKTOPDIR)/$(APPID).desktop'
	$(if $(DESTDIR),, $(POSTINSTALL))

clean:
	$(RM) showdown resources.c *.vala.c version.vala version.txt

check:
	desktop-file-validate share/$(APPID).desktop
	$(foreach UI_FILE, $(filter %.ui, $(RESOURCES)), \
	  NO_AT_BRIDGE=1 gtk-builder-tool validate $(UI_FILE); \
	)


.DEFAULT_GOAL = all
.PHONY: all run install install-home uninstall clean check FORCE
.DELETE_ON_ERROR:
