this.mdbirdSearch = (() => {
  const { ExtensionSupport } = ChromeUtils.importESModule(
    "resource:///modules/ExtensionSupport.sys.mjs"
  );
  const searchers = {};
  ChromeUtils.defineESModuleGetters(searchers, {
    GlodaMsgSearcher: "resource:///modules/gloda/GlodaMsgSearcher.sys.mjs",
    GlodaIMSearcher: "resource:///modules/GlodaIMSearcher.sys.mjs",
  });

  const mainWindowURL = "chrome://messenger/content/messenger.xhtml";
  const indexerPref = "mailnews.database.global.indexer.enabled";
  const htmlNamespace = "http://www.w3.org/1999/xhtml";

  class SidebarSearch {
    constructor(window, extension) {
      this.window = window;
      this.document = window.document;
      this.extension = extension;
      this.tabmail = this.document.getElementById("tabmail");
      this.toolbar = window.gSpacesToolbar;
      this.listeners = new window.AbortController();
      this.styleURL = extension.getURL("search.css");

      this.window.windowUtils.loadSheetUsingURIString(
        this.styleURL,
        this.window.windowUtils.USER_SHEET
      );
      this.createControls();
      this.connectControls();
    }

    createControls() {
      const { document } = this;
      const html = (tag, id) => {
        const element = document.createElementNS(htmlNamespace, tag);
        element.id = id;
        return element;
      };
      const label = this.extension.localizeMessage("search_label");

      this.button = html("button", "mdbird-search-button");
      this.button.type = "button";
      this.button.className = "spaces-toolbar-button";
      this.button.tabIndex = -1;
      this.button.title = label;
      this.button.setAttribute("aria-label", label);
      this.button.setAttribute("aria-haspopup", "dialog");
      this.button.setAttribute("aria-controls", "mdbird-search-panel");
      this.button.setAttribute("aria-expanded", "false");

      const icon = document.createElementNS(htmlNamespace, "img");
      icon.src = "chrome://messenger/skin/icons/new/compact/search.svg";
      icon.alt = "";
      this.button.append(icon);

      this.panel = document.createXULElement("panel");
      this.panel.id = "mdbird-search-panel";
      this.panel.setAttribute("type", "arrow");
      this.panel.setAttribute("noautofocus", "true");
      this.panel.setAttribute("norolluponanchor", "true");
      this.panel.setAttribute("role", "dialog");
      this.panel.setAttribute("aria-label", label);
      this.panel.tabIndex = -1;

      this.form = html("form", "mdbird-search-form");
      this.form.setAttribute("role", "search");

      this.input = html("input", "mdbird-search-input");
      this.input.type = "search";
      this.input.placeholder = this.extension.localizeMessage("search_placeholder");
      this.input.setAttribute("aria-label", label);
      this.input.setAttribute("aria-describedby", "mdbird-search-status");

      this.submit = html("button", "mdbird-search-submit");
      this.submit.type = "submit";
      this.submit.className = "button button-primary";
      this.submit.textContent = this.extension.localizeMessage("search_submit");

      this.status = html("p", "mdbird-search-status");
      this.status.setAttribute("role", "status");
      this.status.hidden = true;

      this.form.append(this.input, this.submit, this.status);
      this.panel.append(this.form);
      document.getElementById("spacesToolbarPopupSet").append(this.panel);
      document.getElementById("mailButton").after(this.button);
    }

    connectControls() {
      const options = { signal: this.listeners.signal };
      this.button.addEventListener("mousedown", event => event.preventDefault(), options);
      this.button.addEventListener("click", () => {
        if (this.panel.state === "open" || this.panel.state === "showing") {
          this.dismiss();
          return;
        }
        this.open(true);
      }, options);

      // Keep the application's localized key and menu entry points.
      const openFromCommand = event => {
        event.stopImmediatePropagation();
        event.preventDefault();
        this.open();
      };
      for (const id of ["key_quickSearchFocus", "glodaSearchCmd"]) {
        this.document.getElementById(id).addEventListener("command", openFromCommand, {
          ...options,
          capture: true,
        });
      }

      this.panel.addEventListener("popupshown", () => {
        this.button.setAttribute("aria-expanded", "true");
        this.focusSearch();
      }, options);
      this.panel.addEventListener("popuphidden", () => {
        const target = this.returnFocusTo;
        this.button.setAttribute("aria-expanded", "false");
        this.returnFocusTo = null;
        if (this.restoreFocus && target) {
          this.window.requestAnimationFrame(() => {
            if (!this.listeners.signal.aborted && this.panel.state === "closed") {
              target.focus();
            }
          });
        }
        this.restoreFocus = false;
      }, options);
      this.window.addEventListener("keydown", event => {
        if (this.panel.state === "open" && event.key === "Escape" && !event.isComposing) {
          event.preventDefault();
          event.stopPropagation();
          this.dismiss();
        }
      }, { ...options, capture: true });

      this.input.addEventListener("input", () => this.updateControls(), options);
      this.form.addEventListener("submit", event => {
        event.preventDefault();
        this.search();
      }, options);
    }

    open(fromButton = false) {
      if (this.tabmail.globalOverlay ||
          this.document.documentElement.classList.contains("customizingUnifiedToolbar")) {
        return;
      }
      if (this.panel.state === "open") {
        this.focusSearch();
        return;
      }
      if (this.panel.state !== "closed") {
        return;
      }

      const buttonVisible = this.button.getClientRects().length > 0;
      const anchor = buttonVisible ? this.button : this.document.getElementById("spacesPinnedButton");
      this.returnFocusTo = fromButton ? this.button : this.document.activeElement;
      if (fromButton && this.toolbar.isLoaded) {
        this.toolbar.setFocusButton(this.button);
      }
      this.updateControls();
      this.panel.openPopup(anchor, buttonVisible ? "end_before" : "after_start");
    }

    updateControls() {
      const enabled = Services.prefs.getBoolPref(indexerPref, true);
      this.input.disabled = !enabled;
      this.submit.disabled = !enabled || !this.input.value.trim();
      this.setStatus(enabled ? null : "index_disabled");
    }

    setStatus(message) {
      this.status.textContent = message ? this.extension.localizeMessage(message) : "";
      this.status.hidden = !message;
    }

    focusSearch() {
      if (this.input.disabled) {
        this.panel.focus();
      } else {
        this.input.focus();
        this.input.select();
      }
    }

    dismiss() {
      this.restoreFocus = true;
      this.panel.hidePopup();
    }

    search() {
      const query = this.input.value.trim();
      this.updateControls();
      if (!query || this.input.disabled) {
        return;
      }

      try {
        const args = { searcher: new searchers.GlodaMsgSearcher(null, query) };
        if (Services.prefs.getBoolPref("mail.chat.enabled", false)) {
          args.IMSearcher = new searchers.GlodaIMSearcher(null, query);
        }
        const mode = Services.prefs.getBoolPref("gloda.show_as_list_by_default", false)
          ? "glodaTableList"
          : "glodaFacet";

        this.tabmail.openTab(mode, args);
      } catch (error) {
        console.error(error);
        this.setStatus("search_error");
        return;
      }
      this.panel.hidePopup();
    }

    destroy() {
      this.listeners.abort();
      this.panel.hidePopup();
      if (this.toolbar.focusButton === this.button) {
        this.toolbar.setFocusButton(this.document.getElementById("mailButton"));
      }
      this.button.remove();
      this.panel.remove();
      this.window.windowUtils.removeSheetUsingURIString(
        this.styleURL,
        this.window.windowUtils.USER_SHEET
      );
    }
  }

  return class extends ExtensionCommon.ExtensionAPI {
    windows = new Map();

    onStartup() {
      ExtensionSupport.registerWindowListener(this.extension.id, {
        chromeURLs: [mainWindowURL],
        onLoadWindow: window => {
          if (!this.windows.has(window)) {
            this.windows.set(window, new SidebarSearch(window, this.extension));
          }
        },
        onUnloadWindow: window => this.windows.delete(window),
      });
    }

    onShutdown(isAppShutdown) {
      ExtensionSupport.unregisterWindowListener(this.extension.id);
      if (!isAppShutdown) {
        for (const search of this.windows.values()) {
          search.destroy();
        }
        Services.obs.notifyObservers(null, "startupcache-invalidate");
      }
      this.windows.clear();
    }
  };
})();
