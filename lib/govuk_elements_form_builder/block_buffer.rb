module GovukElementsFormBuilder
  #
  # This class is intended to be a proxy for a FormBuilder object, and accumulate
  # multiple form elements rendered inside a block. Its main reason for existence is
  # to enable the following syntax when rendering revealing panels:
  #
  # f.radio_button_fieldset :asked_for_help do |fieldset|
  #   fieldset.radio_input(GenericYesNo::YES) do |radio|
  #     # Here, `radio` is a `BlockBuffer` instance, delegating all methods to
  #     # a `FormBuilder` instance, but doing the accumulation/concatenation.
  #     radio.text_field(:help_party)
  #     radio.text_field(:another_field)
  #     [...]
  #   end
  #   fieldset.radio_input(GenericYesNo::NO)
  # end
  #
  class BlockBuffer
    delegate :safe_concat, :send, to: :@form_object

    def initialize(form_object)
      @form_object = form_object
    end

    def method_missing(method, *args, &block)
      safe_concat send(method, *args, &block)
    end
  end
end
