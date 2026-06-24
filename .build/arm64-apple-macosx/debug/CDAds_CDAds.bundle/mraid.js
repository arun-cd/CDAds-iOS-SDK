// CDAds MRAID 3.0 JavaScript Bridge
// Injected into WKWebView before the ad creative loads.
// Communicates with the native layer via window.webkit.messageHandlers.mraid

(function (window) {
  "use strict";

  // ── State ────────────────────────────────────────────────────────────────
  var _state        = "loading";  // loading | default | expanded | resized | hidden
  var _placement    = "inline";   // inline | interstitial
  var _version      = "3.0";
  var _isViewable   = false;
  var _ready        = false;

  var _maxSize      = { width: window.screen.width,  height: window.screen.height };
  var _screenSize   = { width: window.screen.width,  height: window.screen.height };
  var _defaultPos   = { x: 0, y: 0, width: 0, height: 0 };
  var _currentPos   = { x: 0, y: 0, width: 0, height: 0 };

  var _expandProps  = { width: _screenSize.width, height: _screenSize.height,
                        useCustomClose: false, isModal: true };
  var _resizeProps  = { width: 0, height: 0, offsetX: 0, offsetY: 0,
                        customClosePosition: "top-right", allowOffscreen: true };

  var _listeners    = {};   // event → [fn]

  // ── Native bridge helper ─────────────────────────────────────────────────
  function _send(action, params) {
    var payload = params || {};
    payload.action = action;
    try {
      window.webkit.messageHandlers.mraid.postMessage(payload);
    } catch (e) {
      // not running inside native host
    }
  }

  // ── EventEmitter ─────────────────────────────────────────────────────────
  function _emit(event, data) {
    var fns = _listeners[event];
    if (!fns) return;
    for (var i = 0; i < fns.length; i++) {
      try { fns[i](data); } catch (e) {}
    }
  }

  // ── Public API ────────────────────────────────────────────────────────────
  var mraid = {};

  mraid.getVersion = function () { return _version; };

  mraid.addEventListener = function (event, listener) {
    if (!_listeners[event]) _listeners[event] = [];
    _listeners[event].push(listener);
  };

  mraid.removeEventListener = function (event, listener) {
    if (!_listeners[event]) return;
    _listeners[event] = _listeners[event].filter(function (fn) { return fn !== listener; });
  };

  mraid.getState        = function () { return _state; };
  mraid.getPlacementType = function () { return _placement; };
  mraid.isViewable      = function () { return _isViewable; };
  mraid.getMaxSize      = function () { return Object.assign({}, _maxSize); };
  mraid.getScreenSize   = function () { return Object.assign({}, _screenSize); };
  mraid.getDefaultPosition  = function () { return Object.assign({}, _defaultPos); };
  mraid.getCurrentPosition  = function () { return Object.assign({}, _currentPos); };

  mraid.getExpandProperties = function () { return Object.assign({}, _expandProps); };
  mraid.setExpandProperties = function (props) { Object.assign(_expandProps, props); };

  mraid.getResizeProperties = function () { return Object.assign({}, _resizeProps); };
  mraid.setResizeProperties = function (props) { Object.assign(_resizeProps, props); };

  mraid.expand = function (url) {
    _send("expand", { url: url || null });
  };

  mraid.close = function () {
    _send("close");
  };

  mraid.resize = function () {
    _send("resize", {
      width:  _resizeProps.width,
      height: _resizeProps.height,
      offsetX: _resizeProps.offsetX,
      offsetY: _resizeProps.offsetY
    });
  };

  mraid.open = function (url) {
    _send("open", { url: url });
  };

  mraid.playVideo = function (url) {
    _send("playVideo", { url: url });
  };

  mraid.storePicture = function (url) {
    _send("storePicture", { url: url });
  };

  mraid.createCalendarEvent = function (params) {
    _send("createCalendarEvent", params);
  };

  mraid.supports = function (feature) {
    var supported = ["sms", "tel", "calendar", "storePicture", "inlineVideo", "vpaid", "location"];
    return supported.indexOf(feature) !== -1;
  };

  // ── Called by native layer ────────────────────────────────────────────────

  mraid._nativeReady = function (placementType, position) {
    _placement = placementType || "inline";
    if (position) {
      _defaultPos = position;
      _currentPos = Object.assign({}, position);
      _maxSize    = { width: position.maxWidth,  height: position.maxHeight  };
      _screenSize = { width: position.screenWidth, height: position.screenHeight };
    }
    _state = "default";
    _ready = true;
    _emit("ready");
  };

  mraid._nativeStateChange = function (newState) {
    _state = newState;
    _emit("stateChange", newState);
  };

  mraid._nativeViewableChange = function (viewable) {
    _isViewable = viewable;
    _emit("viewableChange", viewable);
  };

  mraid._nativeError = function (action, message) {
    _emit("error", { action: action, message: message });
  };

  mraid._nativeSizeChange = function (w, h) {
    _currentPos.width  = w;
    _currentPos.height = h;
    _emit("sizeChange", { width: w, height: h });
  };

  // Expose
  window.mraid = mraid;

}(window));
