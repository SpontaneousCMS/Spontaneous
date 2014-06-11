// console.log('Loading Content Area...')

Spontaneous.ContentArea = (function($, S) {
	var dom = S.Dom;
	var ContentArea = new JS.Singleton({
		include: Spontaneous.Properties,

		inner: null,
		preview: null,
		editing: null,
		mode: 'edit',

		init: function() {
			var self = this;
			self.wrap  = dom.div("#content-outer");
			self.metaWrap = dom.div("#content-meta").hide();
			self.inner = dom.div('#content');
			self.inner.append(dom.div("#content-loading"));
			self.configureScrollBottomHandler(self.inner);
			self.preview = S.Preview.init(self.inner);
			self.editing = S.Editing.init(self.inner);
			self.service = S.Services.init(self.inner);
			self.wrap.append(self.metaWrap, self.inner);
			return self.wrap;
		},
		configureScrollBottomHandler: function(inner) {
			inner.scroll(function(contentArea, div) {
				var count = 0;
				return function(e) {
					var st = div.scrollTop()
					, ih = div.innerHeight()
					, sh = div[0].scrollHeight
					// don't wait until we're at the exact bottom, but trigger a little bit earlier
					// this should ideally be context sensitive, so that the trigger for short containers
					// loads a bit earlier. This would mean that the first load of additional content would
					// happen more promptly than later ones. Currently it's the inverse of that.
					, margin = 0.95
					, bottom = ((st + ih) >= (sh * margin));
					if (bottom) {
						contentArea.set('scroll_bottom', (++count));
					}
				}
			}(this, inner));
		},
		location_loading: function(destination) {
			if (destination) {
				this.wrap.addClass('loading');
				this.current().showLoading();
			} else {
				this.wrap.removeClass('loading');
				this.current().hideLoading();
			}
		},

		location_changed: function(location) {
			this.goto_page(location);
		},
		display: function(mode) {
			this.mode = mode;
			this.current().display(S.Location.location());
		},
		current: function() {
			this.exitMeta();
			// YUK
			if (this.mode === 'preview') {
				this.editing.hide();
				this.service.hide();
				this.preview.show();
				return this.preview;
			} else if (this.mode === 'edit') {
				this.preview.hide();
				this.service.hide();
				this.editing.show();
				return this.editing;
			} else if (this.mode === 'service') {
				this.preview.hide();
				this.editing.hide();
				this.service.show();
				return this.service;
			}
		},
		goto_page: function(page) {
			this.current().goto_page(page);
		},
		scroll_to_bottom: function(duration, delay) {

			this.inner.delay(delay || 0).animate({ scrollTop:this.inner[0].scrollHeight }, (duration || 1000));
		},
		showService: function(service) {
			if (!this.modeBeforeService) {
				this.modeBeforeService = this.mode;
			}
			this.mode = "service";
			this.current().display(service.url);
		},
		hideService: function() {
			var mode = this.modeBeforeService;
			this.modeBeforeService = false;
			this.display(mode);
		},
		enterMeta: function(view) {
			if (this.metaView === view) { return; }
			this.metaView = view;
			var outer = this.metaWrap.hide();
			this.inner.animate({top: "100%"}, 300, function() {
				if (view && typeof view.show === "function") {
					view.show(outer);
				}
				outer.fadeIn(300);
			});
		},
		exitMeta: function() {
			if (!this.metaView) { return; }
			if (typeof this.metaView.detach === "function") {
				this.metaView.detach();
			}
			this.metaView = null;
			var inner = this.inner, outer = this.metaWrap;
			inner.animate({top: "0%"}, 300, function() {
				outer.empty().hide();
			});
			outer.fadeOut(300);
		}
	});
	return ContentArea;
})(jQuery, Spontaneous);

