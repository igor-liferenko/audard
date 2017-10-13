INCLUDES =						\
	-DG_LOG_DOMAIN=\"Nautilus-Save-Tabs\"	\
	-DDATADIR=\"$(datadir)\"			\
	-DGNOMELOCALEDIR=\""$(datadir)/locale"\" 	\
	-I$(top_srcdir)					\
	-I$(top_builddir)				\
	$(WARN_CFLAGS)                                  \
	-Werror                                         \
	$(DISABLE_DEPRECATED_CFLAGS)			\
	$(NAUTILUS_CFLAGS)				\
	$(GCONF_CFLAGS)					\
	$(GNOMEDESKTOP_CFLAGS)

nautilus_extensiondir=$(NAUTILUS_EXTENSION_DIR)

nautilus_extension_LTLIBRARIES=libnautilus-save-tabs.la

libnautilus_save_tabs_la_SOURCES = \
	nautilus-save-tabs.c       \
	nautilus-save-tabs.h       \
	save-tabs.c

libnautilus_save_tabs_la_LDFLAGS = -module -avoid-version
libnautilus_save_tabs_la_LIBADD  = $(NAUTILUS_LIBS) $(GNOMEVFS_LIBS) $(GCONF_LIBS) $(GNOMEDESKTOP_LIBS)
