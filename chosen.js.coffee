angular.module('yousource.directives', [])

angular.module('yousource.directives').directive 'chosen', ['$timeout', '$parse', ($timeout, $parse) ->

  # This is stolen from Angular...
  NG_OPTIONS_REGEXP = /^\s*(.*?)(?:\s+as\s+(.*?))?(?:\s+group\s+by\s+(.*))?\s+for\s+(?:([\$\w][\$\w]*)|(?:\(\s*([\$\w][\$\w]*)\s*,\s*([\$\w][\$\w]*)\s*\)))\s+in\s+(.*?)(?:\s+track\s+by\s+(.*?))?$/

  # Whitelist of options that will be parsed from the element's attributes and passed into Chosen
  CHOSEN_OPTION_WHITELIST = [
    'noResultsText'
    'allowSingleDeselect'
    'disableSearchThreshold'
    'disableSearch'
    'enableSplitWordSearch'
    'inheritSelectClasses'
    'maxSelectedOptions'
    'placeholderTextMultiple'
    'placeholderTextSingle'
    'searchContains'
    'singleBackstrokeDelete'
    'displayDisabledOptions'
    'displaySelectedOptions'
    'width'
  ]

  snakeCase = (input) -> input.replace /[A-Z]/g, ($1) -> "_#{$1.toLowerCase()}"
  isEmpty = (value) ->
    if angular.isArray(value)
      return value.length is 0
    else if angular.isObject(value)
      return false for key of value when value.hasOwnProperty(key)
    true

  restrict: 'A'
  require: '?ngModel'
  terminal: true
  link: (scope, element, attr, ngModel) ->

    $(element).parent().on 'keyup', ".chosen-container input[type='text']", (event) ->
      #ch-type-ahead-value: storage of typed-ahead value
      if attr.chTypeAheadValue
        current_typed = $(event.target)
        ch_type_ahead_value = $parse(attr.chTypeAheadValue)
        ch_type_ahead_value.assign(scope, current_typed.val())

      #ch-type-ahead-keyup: expression to execute on each keyup
      if attr.chTypeAheadKeyup
        scope.$eval(attr.chTypeAheadKeyup)

    #We save the text before clearing everything in a hidden field
    #We do this because the Angular digest cycle is slow, and when the user types fast,
    #it is not fast enough to keep up witht he user, and gives the illusion that the last 
    #one or 2 characters of the input text is deleted
     $(element).on 'chosen:before_update', ->
       if attr.chTypeAheadValue
         the_container = $(element).parent().find('.chosen-container')
         search_text = the_container.find("input[type='text']").val()
         ch_type_ahead_value = $parse(attr.chTypeAheadValue)
         ch_type_ahead_value.assign(scope, search_text)
         console.log scope.$eval(attr.chTypeAheadValue)

    # the chosen GUI has been updated, all stuff gone
    # Retain typed value to the input
    $(element).on 'chosen:after_update', ->
      if attr.chTypeAheadValue
        search_text = scope.$eval(attr.chTypeAheadValue)
        $(element).parent().find("input[type='text']").val(search_text)
    
    element.addClass('localytics-chosen')

    # Take a hash of options from the chosen directive
    options = scope.$eval(attr.chosen) or {}

    # Options defined as attributes take precedence
    angular.forEach attr, (value, key) ->
      options[snakeCase(key)] = scope.$eval(value) if key in CHOSEN_OPTION_WHITELIST

    startLoading = -> element.addClass('loading').attr('disabled', true).trigger('chosen:updated')
    stopLoading = -> element.removeClass('loading').attr('disabled', false).trigger('chosen:updated')

    chosen = null
    defaultText = null
    empty = false

    initOrUpdate = ->
      if chosen
        element.trigger('chosen:updated')
      else
        chosen = element.chosen(options).data('chosen')
        defaultText = chosen.default_text

    # Use Chosen's placeholder or no results found text depending on whether there are options available
    removeEmptyMessage = ->
      empty = false
      element.attr('data-placeholder', defaultText)

    disableWithMessage = ->
      empty = true
      element.attr('data-placeholder', chosen.results_none_found).attr('disabled', true).trigger('chosen:updated')

    # Watch the underlying ngModel for updates and trigger an update when they occur.
    if ngModel
      origRender = ngModel.$render
      ngModel.$render = ->
        origRender()
        initOrUpdate()

      # This is basically taken from angular ngOptions source.  ngModel watches reference, not value,
      # so when values are added or removed from array ngModels, $render won't be fired.
      if attr.multiple
        viewWatch = -> ngModel.$viewValue
        scope.$watch viewWatch, ngModel.$render, true
    # If we're not using ngModel (and therefore also not using ngOptions, which requires ngModel),
    # just initialize chosen immediately since there's no need to wait for ngOptions to render first
    else initOrUpdate()

    # Watch the disabled attribute (could be set by ngDisabled)
    attr.$observe 'disabled', -> element.trigger('chosen:updated')

    # Watch the collection in ngOptions and update chosen when it changes.  This works with promises!
    # ngOptions doesn't do anything unless there is an ngModel, so neither do we.
    if attr.ngOptions and ngModel
      match = attr.ngOptions.match(NG_OPTIONS_REGEXP)
      valuesExpr = match[7]

      scope.$watchCollection valuesExpr, (newVal, oldVal) ->
        # Defer execution until DOM is loaded
        timer = $timeout(->
          if angular.isUndefined(newVal)
            startLoading()
          else
            element.trigger 'chosen:before_update'
            removeEmptyMessage() if empty
            stopLoading()
            disableWithMessage() if isEmpty(newVal)
            element.trigger 'chosen:after_update'
        )

      scope.$on '$destroy', (event) ->
        $timeout.cancel timer if timer?
]
