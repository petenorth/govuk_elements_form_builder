module GovukElementsFormBuilder
  class FormBuilder < ActionView::Helpers::FormBuilder

    ActionView::Base.field_error_proc = Proc.new do |html_tag, instance|
      add_error_to_html_tag! html_tag, instance
    end

    delegate :content_tag, :tag, :safe_join, :safe_concat, :capture, to: :@template
    delegate :errors, to: :@object

    # Used to propagate the fieldset outer element attribute to the inner elements
    attr_accessor :current_fieldset_attribute

    # Ensure fields_for yields a GovukElementsFormBuilder.
    def fields_for record_name, record_object = nil, fields_options = {}, &block
      super record_name, record_object, fields_options.merge(builder: self.class), &block
    end

    {
      email_field: "govuk-input",
      number_field: "govuk-input",
      password_field: "govuk-input",
      phone_field: "govuk-input",
      range_field: "govuk-input",
      search_field: "govuk-input",
      telephone_field: "govuk-input",
      text_field: "govuk-input",
      url_field: "govuk-input",
      # text_area is, as usual, a special case
      text_area: "govuk-textarea"
    }.each do |method_name, default_field_class|
      define_method(method_name) do |attribute, *args, &block|
        content_tag :div, class: form_group_classes(attribute), id: form_group_id(attribute) do
          options = args.extract_options!

          set_label_classes! options
          set_field_classes! options, attribute, [default_field_class]

          label_text = options.dig(:label_options, :text)
          if label_text
            label = label(attribute, label_text, options[:label_options])
          else
            label = label(attribute, options[:label_options])
          end

          add_hint :label, label, attribute

          block ||= proc { '' }

          after_hint_markup = capture(self, &block)

          (label + after_hint_markup + super(attribute, options.except(:label, :label_options, :width))).html_safe
        end
      end
    end

    def pounds_field(attribute, *args, &block)
      content_tag :div, class: form_group_classes(attribute), id: form_group_id(attribute) do
        options = args.extract_options!

        set_label_classes! options
        set_field_classes! options, attribute, ['govuk-input']

        label = label(attribute, options[:label_options])

        add_hint :label, label, attribute

        original_number_field = method(:number_field).super_method
        rails_number_field = original_number_field.call(attribute, options.except(:label, :label_options, :width))

        pound_sign = content_tag :div, class: 'govuk-currency-input__symbol' do
          '£'
        end

        pounds_container = content_tag :div, class: 'govuk-currency-input' do
          pound_sign + rails_number_field
        end

        (label + pounds_container).html_safe
      end
    end

    def radio_button_fieldset attribute, options={}, &block
      classes = %w(govuk-radios govuk-radios__inline)
      if options[:small]
        classes << 'govuk-radios--small'
      else
        classes << 'govuk-radios--conditional'
      end
      classes << 'govuk-radios--inline' if options[:inline]

      content_tag :div,
                  class: form_group_classes(attribute),
                  id: form_group_id(attribute) do
        content_tag :fieldset, fieldset_options(attribute, options) do
          content_tag(:div, {class: classes.join(' '), "data-module" => "radios"}) do

            safe_join([
                        fieldset_legend(attribute, options, heading: options.fetch(:fieldset_heading, true)),
                        block_given? ? capture(self, &block) : radio_inputs(attribute, options)
                      ], "\n")
          end
        end
      end
    end

    def check_box_fieldset legend_key, attributes, options={}, &block
      content_tag :div,
                  class: form_group_classes(attributes),
                  id: form_group_id(attributes) do
        content_tag :fieldset, fieldset_options(attributes, options) do
          content_tag(:div, {class: "govuk-checkboxes", "data-module" => "checkboxes"}) do
            safe_join([
                        fieldset_legend(legend_key, options, heading: true),
                        block_given? ? capture(self, &block) : check_box_inputs(attributes, options)
                      ], "\n")
          end
        end
      end
    end

    def collection_select(method, collection, value_method, text_method, options = {}, *args, &block)
      content_tag :div, class: form_group_classes(method), id: form_group_id(method) do

        html_options = args.extract_options!
        label_options = html_options.delete(:label_options) || {}

        set_field_classes!(html_options, method, 'govuk-select')

        label = label(method, { class: "govuk-label" }.merge(label_options))
        add_hint :label, label, method


        block ||= proc { '' }

        after_hint_markup = capture(self, &block)
        puts 'here' * 80
        puts after_hint_markup

        (label + after_hint_markup + super(method, collection, value_method, text_method, options, html_options)).html_safe
      end
    end

    def collection_check_boxes(method, collection, value_method, text_method, options = {}, *args)
      content_tag(:div,
                  class: form_group_classes(method),
                  id: form_group_id(method)) do
        content_tag(:fieldset, fieldset_options(method, options)) do
          legend_key = method
          legend = fieldset_legend(legend_key, options)

          collection = content_tag(:div, {class: 'govuk-checkboxes', 'data-module' => 'checkboxes'}) do
            super(method, collection, value_method, text_method, options) do |b|
              content_tag(:div, class: "govuk-checkboxes__item") do
                safe_join([
                  b.check_box(class: %w{govuk-checkboxes__input}),
                  b.label(class: %w{govuk-label govuk-checkboxes__label})
                ])
              end
            end
          end

          (legend + collection).html_safe
        end
      end
    end

    def collection_radio_buttons method, collection, value_method, text_method, options = {}, *args
      content_tag(:div,
        class: form_group_classes(method),
        id: form_group_id(method)) do
          content_tag(:fieldset, fieldset_options(method, options)) do

            legend_key = method
            legend = fieldset_legend(legend_key, options)

            collection = content_tag(:div, {class: "govuk-radios", "data-module" => "radios"}) do
              super(method, collection, value_method, text_method, options) do |b|
                content_tag :div, class: "govuk-radios__item" do
                    b.radio_button(class: %w{govuk-radios__input}) +
                      b.label(class: %w{govuk-label govuk-radios__label})
                end
              end
            end

            (legend + collection).html_safe

          end
        end
    end

    # The following method will generate revealing panel markup and internally call the
    # `radio_inputs` private method. It is not intended to be used outside a
    # fieldset tag (at the moment, `radio_button_fieldset`).
    #
    def radio_input choice, options = {}, &block
      fieldset_attribute = self.current_fieldset_attribute

      panel = if block_given? || options.key?(:panel_id)
        panel_id = options.delete(:panel_id) { [fieldset_attribute, choice, 'panel'].join('_') }
        options.merge!('data-aria-controls' => panel_id)
        revealing_panel(panel_id, 'radios', flush: false, &block) if block_given?
      end

      option = radio_inputs(
        fieldset_attribute,
        options.merge(choices: [choice])
      ).first + "\n"

      safe_join([option, panel])
    end

    # The following method will generate revealing panel markup and internally call the
    # `check_box_inputs` private method. It is not intended to be used outside a
    # fieldset tag (at the moment, `check_box_fieldset`).
    #
    def check_box_input attribute, options = {}, &block
      panel = if block_given? || options.key?(:panel_id)
                panel_id = options.delete(:panel_id) { [attribute, 'panel'].join('_') }
                options.merge!('data-aria-controls' => panel_id)
                revealing_panel(panel_id, 'checkboxes', flush: false, &block) if block_given?
              end

      checkbox = check_box_inputs([attribute], options).first + "\n"

      safe_join([checkbox, panel])
    end

    def revealing_panel panel_id, element_type = "checkboxes", options = {}, &block

      unless %w{radios checkboxes}.include?(element_type)
        Rails.logger.warn("Revealing panels only work for radios and checkboxes")
      end

      panel = content_tag(
        :div, class: "govuk-#{element_type}__conditional govuk-#{element_type}__conditional--hidden", id: panel_id
      ) { block.call(BlockBuffer.new(self)) } + "\n"

      options.fetch(:flush, true) ? safe_concat(panel) : panel
    end

    def submit(value = nil, options = {})
      super(value, {class: "govuk-button"}.merge(options))
    end

    def date_field(attribute, date_of_birth: false, readonly: false, disabled: false, **options)
      content_tag :div, class: form_group_classes(attribute), id: form_group_id(attribute) do
        content_tag :fieldset, fieldset_options(attribute, options) do

          date_inputs = content_tag(:div, class: 'govuk-date-input') do |di|

            with_options(date_of_birth: date_of_birth, readonly: readonly,
              disabled: disabled) do |frm|

              safe_join([
                frm.date_input_form_group(attribute, segment: :day),
                frm.date_input_form_group(attribute, segment: :month),
                frm.date_input_form_group(attribute, segment: :year, width: 4)
              ])
            end

          end

          safe_join([
            fieldset_legend(attribute, options),
            date_inputs
          ])
        end
      end
    end

    def text_area_with_maxwords(attribute, options = {}, &block)
      maxwords = options.delete :maxwords || {}
      maxword_count = maxwords.fetch :count, 50

      content_tag :div, class: %w(govuk-character-count), 'data-module' => "character-count", 'data-maxwords' => maxword_count do
        text_area attribute, **options, class: 'js-character-count', &block
      end
    end

    def form_group_id attribute
      "#{attribute_prefix}_#{attribute}_container"
    end

    private

    # Gov.UK Design System date inputs require a fieldset containing
    # separate number inputs for Day, Month and Year. Rails' handling
    # requires they are named with 3i, 2i and 1i prefix respectively
    def date_input_form_group(attribute, segment: :day, width: 2, date_of_birth:, **options)
      segments = {day: '3i', month: '2i', year: '1i'}
      autocomplete_segments = {
        day: 'bday bday-day',
        month: 'bday bday-month',
        year: 'bday bday-year'
      }

      content_tag(:div, class: %w{govuk-date-input__item}) do

        date_input_options = {
          class: %w{govuk-input govuk-date-input__input}.push(width_class(width)),
          type: 'number',
          pattern: '[0-9]*',
        }

        if date_of_birth
          date_input_options[:autocomplete] = autocomplete_segments[segment]
        end

        attribute_segment = "#{attribute}(#{segments[segment]})"
        input_name = "#{attribute_prefix}[#{attribute_segment}]"
        input_value = @object.try(attribute).try(segment)
        input_id = [attribute_prefix, attribute, segments[segment]].join('_')

        input_tag = tag \
          :input,
          date_input_options.merge({
            name: input_name,
            value: input_value,
            id: input_id
          }).merge(options)

        input_label = content_tag \
          :label,
          segment.capitalize,
          for: input_id,
          class: %w{govuk-label govuk-date-input__label}

        safe_join [input_label, input_tag]
      end
    end


    def width_class(width)
      case width
      # fixed (character) widths
      when 20 then 'govuk-input--width-20'
      when 10 then 'govuk-input--width-10'
      when 5  then 'govuk-input--width-5'
      when 4  then 'govuk-input--width-4'
      when 3  then 'govuk-input--width-3'
      when 2  then 'govuk-input--width-2'

      # fluid widths
      when 'full'           then 'govuk-!-width-full'
      when 'three-quarters' then 'govuk-!-width-three-quarters'
      when 'two-thirds'     then 'govuk-!-width-two-thirds'
      when 'one-half'       then 'govuk-!-width-one-half'
      when 'one-third'      then 'govuk-!-width-one-third'
      when 'one-quarter'    then 'govuk-!-width-one-quarter'

      # default
      else 'govuk-input--width-20'
      end
    end

    # Given an attributes hash that could include any number of arbitrary keys, this method
    # ensure we merge one or more 'default' attributes into the hash, creating the keys if
    # don't exist, or merging the defaults if the keys already exists.
    # It supports strings or arrays as values.
    #
    def merge_attributes attributes, default:
      hash = attributes || {}
      hash.merge(default) { |_key, oldval, newval| Array(newval) + Array(oldval) }
    end

    def set_field_classes!(options, attribute, classes=['govuk-input'])
      classes << 'govuk-input--error' if error_for?(attribute)

      if width = options.dig(:width)
        classes << width_class(width)
      end

      options ||= {}
      options.merge!(
        merge_attributes(options, default: {class: classes})
      )

    end

    def set_label_classes!(options = {})
      options[:label_options] ||= {}

      return if options[:label_options].delete :overwrite_defaults!

      options[:label_options].merge! \
        merge_attributes(options[:label_options], default: {class: 'govuk-label'})
    end

    def check_box_inputs attributes, options
      attributes.map do |attribute|
        input = check_box(attribute, {class: "govuk-checkboxes__input"}.merge(options))
        label = label(attribute, class: "govuk-label govuk-checkboxes__label") do |tag|
          options.dig(:label_options, :text) || localized_label("#{attribute}")
        end
        content_tag :div, {class: 'govuk-checkboxes__item'}.merge(options.slice(:class, 'data-aria-controls')) do
          input + label
        end
      end
    end

    def radio_inputs attribute, options
      choices = options[:choices] || [ :yes, :no ]

      choices.map do |choice|
        value = choice.send(options[:value_method] || :to_s)
        input = radio_button(
          attribute,
          value,
          {class: 'govuk-radios__input'}.merge(options)
        )
        label = label(attribute, class: 'govuk-label govuk-radios__label', value: value) do |tag|
          if options.has_key? :text_method
            choice.send(options[:text_method])
          else
            localized_label("#{attribute}.#{choice}")
          end
        end
        content_tag :div, {class: 'govuk-radios__item'} do
          input + label
        end
      end

    end

    def fieldset_legend(attribute, options, heading: false)
      heading = options[:heading] || heading
      page_heading = options[:page_heading]

      legend_classes = %w{govuk-fieldset__legend}

      if page_heading
        legend_classes << 'govuk-fieldset__legend--l'
      elsif heading
        legend_classes << 'govuk-fieldset__legend--m'
      end

      legend = content_tag('legend', class: legend_classes) do

        tags = []

        if page_heading
          tags << content_tag(
            'h1',
            fieldset_text(attribute),
            merge_attributes(options[:legend_options], default: {class: 'govuk-fieldset__heading'})
          )
        elsif heading
          tags << content_tag(
            'h2',
            fieldset_text(attribute),
            merge_attributes(options[:legend_options], default: {class: 'govuk-fieldset__heading'})
          )
        else
          tags << content_tag(
            :span,
            fieldset_text(attribute),
            merge_attributes(options[:legend_options], default: {class: 'govuk-label'})
          )
        end

        if error_for? attribute
          tags << content_tag(
            :span,
            error_full_message_for(attribute),
            class: 'govuk-error-message'
          )
        end

        hint = hint_text attribute
        tags << content_tag(:span, hint, class: 'govuk-hint') if hint

        safe_join tags
      end
      legend.html_safe
    end

    def fieldset_options attribute, options
      self.current_fieldset_attribute = attribute

      fieldset_options = {}
      fieldset_options[:class] = ['govuk-fieldset']
      fieldset_options[:class] << 'inline' if options[:inline] == true
      fieldset_options
    end

    private_class_method def self.add_error_to_html_tag! html_tag, instance
      object_name = instance.instance_variable_get(:@object_name)
      object = instance.instance_variable_get(:@object)

      case html_tag
      when /^<label/
        add_error_to_label! html_tag, object_name, object
      when /^<input/
        add_error_to_input! html_tag, 'input'
      when /^<textarea/
        add_error_to_input! html_tag, 'textarea'
      else
        html_tag
      end
    end

    def self.attribute_prefix object_name
      object_name.to_s.tr('[]','_').squeeze('_').chomp('_')
    end

    def attribute_prefix
      self.class.attribute_prefix(@object_name)
    end

    private_class_method def self.add_error_to_label! html_tag, object_name, object
      field = html_tag[/for="([^"]+)"/, 1]
      object_attribute = object_attribute_for field, object_name
      message = error_full_message_for object_attribute, object_name, object
      if message
        html_tag.sub(
          '</label',
          %Q{<span class="govuk-error-message" id="error_message_#{field}">#{message}</span></label}
        ).html_safe # sub() returns a String, not a SafeBuffer
      else
        html_tag
      end
    end

    private_class_method def self.add_error_to_input! html_tag, element
      field = html_tag[/id="([^"]+)"/, 1]
      html_tag.sub(
        element,
        %Q{#{element} aria-describedby="error_message_#{field}"}
      ).html_safe # sub() returns a String, not a SafeBuffer
    end

    def form_group_classes(attributes)
      %w{govuk-form-group}.tap do |classes|
        if Array.wrap(attributes).find {|a| error_for?(a)}
          classes << 'govuk-form-group--error'
        end
      end
    end

    def self.error_full_message_for attribute, object_name, object
      message = object.errors.full_messages_for(attribute).first
      message&.sub default_label(attribute), localized_label(attribute, object_name)
    end

    def error_full_message_for attribute
      self.class.error_full_message_for attribute, @object_name, @object
    end

    def error_for? attribute
      object.respond_to?(:errors) &&
      errors.messages.key?(attribute) &&
      !errors.messages[attribute].empty?
    end

    private_class_method def self.object_attribute_for field, object_name
      field.to_s.
        sub("#{attribute_prefix(object_name)}_", '').
        to_sym
    end

    def add_hint(tag, element, name)
      hints = Array hint_text(name)

      hint_tags = hints.map do |hint|
        content_tag :span, hint, class: 'govuk-hint'
      end.join.html_safe

      if element.include? 'class="govuk-error-message"'
        element.sub! \
          '<span class="govuk-error-message"',
          %Q{#{hint_tags}<span class="govuk-error-message"}
      else
        element.sub! "</#{tag}>", "#{hint_tags}</#{tag}>".html_safe
      end
    end

    def fieldset_text attribute
      localized 'helpers.fieldset', attribute, default_label(attribute)
    end

    def hint_text attribute
      localized 'helpers.hint', attribute, ''
    end

    def self.default_label attribute
      attribute.to_s.split('.').last.humanize.capitalize
    end

    def default_label attribute
      self.class.default_label attribute
    end

    def self.localized_label attribute, object_name
      localized 'helpers.label', attribute, default_label(attribute), object_name
    end

    def localized_label attribute
      self.class.localized_label attribute, @object_name
    end

    def self.localized scope, attribute, default, object_name
      key = "#{object_name}.#{attribute}"
      translate key, default, scope
    end

    def self.translate key, default, scope
      # Passes blank String as default because nil is interpreted as no default
      I18n.translate(key, default: '', scope: scope).presence ||
      I18n.translate("#{key}_html", default: default, scope: scope).html_safe.presence
    end

    def localized scope, attribute, default
      self.class.localized scope, attribute, default, @object_name
    end

  end
end
