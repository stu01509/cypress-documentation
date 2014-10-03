@App.module "TestIframeApp.Show", (Show, App, Backbone, Marionette, $, _) ->

  class Show.Iframe extends App.Views.ItemView
    template: "test_iframe/show/iframe"

    ui:
      # header:   "header"
      size:     "#iframe-size-container"
      expand:   ".fa-expand"
      compress: ".fa-compress"
      message:  "#iframe-message"
      dropdown: ".dropdown"
      sliders:  ".slider"
      button:   ".dropdown-toggle"
      choices:  ".dropdown-menu li a"

    events:
      "click @ui.expand"    : "expandClicked"
      "click @ui.compress"  : "compressClicked"
      "click @ui.button"    : "buttonClicked"
      "click @ui.choices"   : "choicesClicked"
      "show.bs.dropdown"    : "dropdownShow"
      "hide.bs.dropdown"    : "dropdownHide"

    choicesClicked: (e) ->
      e.preventDefault()

    buttonClicked: (e) ->
      e.stopPropagation()
      @ui.button.parent().toggleClass("open")

    getBootstrapNameSpaceForEvent: (name, e) ->
      name + "." + e.namespace

    dropdownShow: (e) ->
      return if not @$iframe

      ## the bootstrap namespace for click events
      ## ie click.bs.bootstrap
      eventNamespace = @getBootstrapNameSpaceForEvent("click", e)

      ## binds to the $iframe document's click event
      ## and repropogates this to our document
      ## we do this because bootstrap will only bind
      ## to our documents click event and not our iframes
      ## so clicking into our iframe should close the dropdown
      @$iframe.contents().one eventNamespace, (e) =>
        $(document).trigger(eventNamespace, e)

    dropdownHide: (e) ->
      return if not @$iframe

      ## the bootstrap namespace for click events
      ## ie click.bs.bootstrap
      eventNamespace = @getBootstrapNameSpaceForEvent("click", e)

      ## we always want to remove our old custom handlers
      ## when the drop down is closed to clean up references
      @$iframe.contents().off eventNamespace

    revertToDom: (dom, options) ->
      ## replaces the iframes body with the dom object
      dom.replaceAll @$el.find("#iframe-remote").contents().find("body")

      @addRevertMessage(options)

      if options.el
        @highlightEl options.el,
          id:   options.id
          attr: options.attr
          dom:  dom

    addRevertMessage: (options) ->
      @reverted = true
      @ui.message.text("DOM has been reverted").show()

    getZIndex: (el) ->
      if /^(auto|0)$/.test el.css("zIndex") then 1000 else Number el.css("zIndex")

    highlightEl: (el, options = {}) ->
      _.defaults options,
        init: true

      @$remote.contents().find("[data-highlight-el]").remove() if not @reverted

      return if not options.init

      ## if we're not currently reverted
      ## and init is false then nuke the currently highlighted el
      # if not @reverted and not options.init
        # return @$iframe.contents().find("[data-highlight-el='#{options.id}']").remove()

      if options.dom
        dom = options.dom
        el  = options.dom.find("[" + options.attr + "]")
      else
        dom = @$remote.contents().find("body")

      el.each (index, el) =>
        el = $(el)

        ## bail if our el no longer exists in the parent dom
        return if not @elExistsInDocument(dom, el)

        ## bail if our el isnt visible either
        return if not el.is(":visible")

        dimensions = @getDimensions(el)

        ## dont show anything if our element displaces nothing
        return if dimensions.width is 0 or dimensions.height is 0

        _.defer =>
          div = App.request("element:box:model:layers", el, dom)
          div.attr("data-highlight-el", options.id)

    elExistsInDocument: (parent, el) ->
      $.contains parent[0], el[0]

    getDimensions: (el) ->
      {
        width: el.width()
        height: el.height()
      }

    calcWidth: (main, tests, container) ->
      container.width main.width() - tests.width()

    updateIframeCss: (name, val) ->
      switch name
        when "height", "width"
          @ui.size.css(name, val + "%")
        when "scale"
          num = (val / 100)
          @ui.size.css("transform", "scale(#{num})")

    onShow: ->
      main      = $("#main-region :first-child")
      tests     = $("#test-container")
      container = $("#iframe-wrapper")

      view = @

      @ui.sliders.slider
        range: "min"
        min: 1
        max: 100
        slide: (e, ui) ->
          name = $(@).parents(".form-group").find("input").val(ui.value).prop("name")
          view.updateIframeCss(name, ui.value)

      @ui.sliders.each (index, slider) ->
        $slider = $(slider)
        val = $slider.parents(".form-group").find("input").val()
        $slider.slider("value", val)

      @calcWidth = _(@calcWidth).partial main, tests, container

      $(window).on "resize", @calcWidth

      # @ui.header.hide()
      @ui.compress.hide()

    onDestroy: ->
      $(window).off "resize", @calcWidth

      # _.each ["Ecl", "$", "jQuery", "parent", "chai", "expect", "should", "assert", "Mocha", "mocha"], (global) =>
      #   delete @$iframe[0].contentWindow[global]
      @$iframe?.remove()
      @$remote?.remove()

      delete @$remote
      delete @$iframe
      delete @fn

    loadIframe: (src, fn) ->
      ## remove any existing iframes
      @reverted = false
      @ui.message.hide().empty()

      @$remote?.remove()
      @$iframe?.remove()

      @$el.hide()

      view = @

      @src = "/iframes/" + src
      @fn = fn

      # @$iframe = window.open(@src, "testIframeWindow", "titlebar=no,menubar=no,toolbar=no,location=no,personalbar=no,status=no")
      # @$iframe.onload = =>
      #   fn(@$iframe)

      @$remote = $ "<iframe />",
        id: "iframe-remote"

        src: @src
        id: "iframe-spec"
        load: ->
          fn(@contentWindow, view.remote)
          view.$el.show()
          view.calcWidth()
          # view.ui.header.show()

      @$remote.appendTo(@ui.size)
      @$iframe.appendTo(@$el)

    expandClicked: (e) ->
      @ui.expand.hide()
      @ui.compress.show()

      @$el.find("iframe").hide()
      ## display the iframe header in an 'external' mode
      ## swap out fa-expand with fa-compress

      @externalWindow = window.open(@src, "testIframeWindow", "titlebar=no,menubar=no,toolbar=no,location=no,personalbar=no,status=no")
      # console.warn @externalWindow, @fn
      # @externalWindow.onload =>
        # console.warn "externalWindow ready!"
        # @fn(@externalWindow)

      # @externalWindow
      ## when the externalWindow is open, keep the iframe around but proxy
      ## the ECL and dom commands to it

    compressClicked: (e) ->
      @ui.compress.hide()
      @ui.expand.show()

      @$el.find("iframe").show()
      @externalWindow.close?()
