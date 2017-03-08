module GovukElementsErrorsHelper

  class << self
    include ActionView::Context
    include ActionView::Helpers::TagHelper
  end

  def self.error_summary object, heading, description
    puts ">>>>>>>>>>>>>>  #{__FILE__}:#{__LINE__} <<<<<<<<<<<<<<<<<\n"
    # @object_ids = Set.new
    puts ">>>>>>>>>>>>>>  #{__FILE__}:#{__LINE__} <<<<<<<<<<<<<<<<<\n"
    return unless errors_exist? object
    puts ">>>>>>>>>>>>>>  #{__FILE__}:#{__LINE__} <<<<<<<<<<<<<<<<<\n"
    error_summary_div do
      puts ">>>>>>>>>>>>>>  #{__FILE__}:#{__LINE__} <<<<<<<<<<<<<<<<<\n"
      error_summary_heading(heading) +
      error_summary_description(description) +
      error_summary_list(object)
    end
  end

  def self.errors_exist? object
    errors_present?(object) || child_errors_present?(object)
  end

  def self.child_errors_present? object
    @object_ids = Set.new
    attributes(object).any? { |child| errors_exist?(child) }
  end

  def self.attributes object
    child_objects = attribute_objects object
    nested_child_objects = child_objects.reject { |o| @object_ids.include?(o) }.map { |o| @object_ids << o; attributes(o) }
    (child_objects + nested_child_objects).flatten
  end

  def self.attribute_objects object
    @object_ids = Set.new

    attr_objects = object.
      instance_variables.
      map { |var| instance_variable(object, var) }.
      compact
    # don't return any objects that we've seen before
    # attr_objects.delete_if { |ao| @object_ids.include?(ao.object_id) }
    # @object_ids.merge attr_objects.map(&:object_id)
    attr_objects
  end

  def self.child_to_parent object, parents={}

    aos = attribute_objects(object)
    aos.reject { |o| @objects.include?(o) }.each do |child|
    # attribute_objects(object).each do |child|
      @objects << child
      parents[child] = object
      child_to_parent child, parents
    end
    parents
  end

  def self.instance_variable object, var
    field = var.to_s.sub('@','').to_sym
    object.send(field) if object.respond_to?(field)
  end

  def self.errors_present? object
    object && object.respond_to?(:errors) && object.errors.present?
  end

  def self.children_with_errors object
    @object_ids = Set.new
    attributes(object).select { |child| errors_present?(child) }
  end

  def self.error_summary_div &block
    content_tag(:div,
        class: 'error-summary',
        role: 'group',
        aria: {
          labelledby: 'error-summary-heading'
        },
        tabindex: '-1') do
      yield block
    end
  end

  def self.error_summary_heading text
    content_tag :h1,
      text,
      id: 'error-summary-heading',
      class: 'heading-medium error-summary-heading'
  end

  def self.error_summary_description text
    content_tag :p, text
  end

  def self.error_summary_list object
    puts ">>>>>>>>>>>>>>  #{__FILE__}:#{__LINE__} <<<<<<<<<<<<<<<<<\n"
    content_tag(:ul, class: 'error-summary-list') do
      puts ">>>>>>>>>>>>>>  #{__FILE__}:#{__LINE__} <<<<<<<<<<<<<<<<<\n"
      # @object_ids = Set.new
      puts ">>>>>>>>>>>>>>  #{__FILE__}:#{__LINE__} <<<<<<<<<<<<<<<<<\n"
      @objects = Set.new
      child_to_parents = child_to_parent(object)
      puts ">>>>>>>>>>>>>>  #{__FILE__}:#{__LINE__} <<<<<<<<<<<<<<<<<\n"
      messages = error_summary_messages(object, child_to_parents)
      puts ">>>>>>>>>>>>>>  #{__FILE__}:#{__LINE__} <<<<<<<<<<<<<<<<<\n"
      # @object_ids = Set.new
      puts ">>>>>>>>>>>>>>  #{__FILE__}:#{__LINE__} <<<<<<<<<<<<<<<<<\n"
      messages << children_with_errors(object).map do |child|
        puts ">>>>>>>>>>>>>>  #{__FILE__}:#{__LINE__} <<<<<<<<<<<<<<<<<\n"
        error_summary_messages(child, child_to_parents)
      end

      messages.flatten.join('').html_safe
    end
  end

  def self.error_summary_messages object, child_to_parents
    puts ">>>>>>>>>>>>>>  #{__FILE__}:#{__LINE__} <<<<<<<<<<<<<<<<<\n"
    object.errors.keys.map do |attribute|
      puts ">>>>>>>>>>>>>>  #{__FILE__}:#{__LINE__} <<<<<<<<<<<<<<<<<\n"
      error_summary_message object, attribute, child_to_parents
    end
  end

  def self.error_summary_message object, attribute, child_to_parents
    puts ">>>>>>>>>>>>>>  #{__FILE__}:#{__LINE__} <<<<<<<<<<<<<<<<<\n"
    messages = object.errors.full_messages_for attribute
    puts ">>>>>>>>>>>>>>  #{__FILE__}:#{__LINE__} <<<<<<<<<<<<<<<<<\n"
    messages.map do |message|
      puts ">>>>>>>>>>>>>>  #{__FILE__}:#{__LINE__} <<<<<<<<<<<<<<<<<\n"
      object_prefixes = object_prefixes object, child_to_parents
      puts ">>>>>>>>>>>>>>  #{__FILE__}:#{__LINE__} <<<<<<<<<<<<<<<<<\n"
      link = link_to_error(object_prefixes, attribute)
      puts ">>>>>>>>>>>>>>  #{__FILE__}:#{__LINE__} <<<<<<<<<<<<<<<<<\n"
      message.sub! default_label(attribute), localized_label(object_prefixes, attribute)
      content_tag(:li, content_tag(:a, message, href: link))
    end
    puts ">>>>>>>>>>>>>>  #{__FILE__}:#{__LINE__} <<<<<<<<<<<<<<<<<\n"
  end

  def self.link_to_error object_prefixes, attribute
    ['#error', *object_prefixes, attribute].join('_')
  end

  def self.default_label attribute
    attribute.to_s.humanize.capitalize
  end

  def self.localized_label object_prefixes, attribute
    object_key = object_prefixes.shift
    object_prefixes.each { |prefix| object_key += "[#{prefix}]" }
    key = "#{object_key}.#{attribute}"
    I18n.t(key,
      default: default_label(attribute),
      scope: 'helpers.label').presence
  end

  def self.parents_list object, child_to_parents
    puts ">>>>>>>>>>>>>>  #{__FILE__}:#{__LINE__} <<<<<<<<<<<<<<<<<\n"

    if parent = child_to_parents[object]
      puts ">>>>>>>>>>>>>>  #{__FILE__}:#{__LINE__} <<<<<<<<<<<<<<<<<\n"
      @objects = Set.new
      [].tap do |parents|
        while parent
          puts ">>>>>>>>>>>>>>  #{__FILE__}:#{__LINE__} <<<<<<<<<<<<<<<<<\n"
          parents.unshift parent
          parent = child_to_parents[parent]
          break if @objects.include?(parent)
          @objects << parent
        end
      end
    end
  end

  def self.object_prefixes object, child_to_parents
    puts ">>>>>>>>>>>>>>  #{__FILE__}:#{__LINE__} <<<<<<<<<<<<<<<<<\n"
    parents = parents_list object, child_to_parents
    puts ">>>>>>>>>>>>>>  #{__FILE__}:#{__LINE__} <<<<<<<<<<<<<<<<<\n"
    if parents.present?
      root = parents.shift
      prefixes = [underscore_name(root)]
      parents.each { |p| prefixes << "#{underscore_name p}_attributes" }
      prefixes << "#{underscore_name object}_attributes"
    else
      prefixes = [underscore_name(object)]
    end
  end

  def self.underscore_name object
    object.class.name.underscore
  end

  private_class_method :error_summary_div
  private_class_method :error_summary_heading
  private_class_method :error_summary_description
  private_class_method :error_summary_messages

end
