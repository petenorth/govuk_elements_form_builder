require 'rails_helper'
require 'spec_helper'

class TestHelper < ActionView::Base; end

RSpec.describe GovukElementsFormBuilder::FormBuilder do
  include TranslationHelper

  it "should have a version" do
    expect(GovukElementsFormBuilder::VERSION).to eq("1.2.0")
  end

  let(:helper) {TestHelper.new}
  let(:resource) {Person.new}
  let(:resource_name) {:person}
  let(:builder) {described_class.new resource_name, resource, helper, {}}

  shared_examples_for 'input field' do |method, type|

    let(:element) {method.eql?(:text_area) ? "textarea" : "input"}

    let(:attribute) {:name}
    subject {builder.send(method, attribute)}

    specify 'outputs label and input wrapped in div' do
      expect(subject).to have_tag('div.govuk-form-group') do |fg|
        expect(fg).to have_tag("label.govuk-label", with: {for: [resource_name, attribute].join('_')})

        class_selector = (method == :text_area) ? 'govuk-textarea' : 'govuk-input'
        expect(fg).to have_tag("#{element}.#{class_selector}", with: {name: "#{resource_name}[#{attribute}]"})
      end
    end

    context 'inputs' do

      context "one custom input class (passed as a string)" do
        let(:custom_class) {"blue-and-white-stripes"}
        subject { builder.send(method, :name, class: custom_class) }

        specify 'adds custom class to input when provided' do
          expect(subject).to have_tag("#{element}.#{custom_class}", with: {type: type}.compact)
        end
      end

      context "multiple custom input classes (passed as an array)" do
        let(:custom_classes) {["blue-and-white-stripes", "yellow-spots"]}
        subject { builder.send(method, :name, class: custom_classes) }

        specify 'adds multiple custom classes to input when provided' do
          expect(subject).to have_tag("#{element}.#{custom_classes.join(".")}", with: {type: type}.compact)
        end
      end

      context "custom html attributes" do

        let(:custom_attributes) {method.eql?(:text_area) ? {cols: '100'} : {size: '100'}}

        subject {builder.send(method, :name, nil, custom_attributes.dup)}

        specify 'adds all supplied html attributes' do
          expect(subject).to have_tag(element, with: custom_attributes)
        end

      end

      context 'widths' do


          specify "should add class the correct width classes" do
            {
              20           => 'govuk-input--width-20',
              5            => 'govuk-input--width-5',
              'two-thirds' => 'govuk-\!-width-two-thirds',
              'full'       => 'govuk-\!-width-full'
            }.each do |arg, width_class|
            expect(builder.send(method, :name, width: arg)).to have_tag(element, with: {class: width_class})
          end

        end
      end

    end

    context 'labels' do

      context "one custom label attributes" do
        let(:label_options) {{"data-some-value" => "XYZ", lang: "en"}}
        subject { builder.send(method, :name, label_options: label_options) }

        specify 'adds custom class to input when provided' do
          expect(subject).to have_tag("label", with: label_options)
        end
      end
      
      context 'custom label text' do
        let(:label_options) {{text: 'Custom label'}}
        subject { builder.send(method, :name, label_options: label_options) }
        
        specify 'shows custom label text' do
          expect(subject).to have_tag("label", text: 'Custom label')
        end
      end

    end

    context 'hints' do

      subject {builder.send(method, :ni_number)}
      let(:hint_text) {I18n.t('helpers.hint.person.ni_number')}

      specify 'should include hint text' do
        expect(subject).to have_tag('.govuk-form-group > label.govuk-label') do |label|
          expect(label).to have_tag("span.govuk-hint", text: hint_text)
        end
      end

    end

    context 'fields_for' do

      let(:attribute) {:postcode}

      subject do
        builder.fields_for(:address, Address.new) do |f|
          f.send method, attribute
        end
      end

      specify 'should output input with nested form attributes' do
        expect(subject).to have_tag("#{element}#person_address_attributes_#{attribute}", with: {
          name: "person[address_attributes][#{attribute}]"
        })
      end

      specify 'should display a label for the nested field' do
        expect(subject).to have_tag('label', with: {
          for: "person_address_attributes_#{attribute}"
        })
      end

    end

    context 'when resource is a not a persisted model' do
      let(:resource) {Report.new}
      subject {described_class.new(:report, resource, helper, {})}

      it "##{method} does not raise errors" do
        expect {subject.send method, :name}.not_to raise_error
      end
    end

    context 'validation errors' do

      let(:attribute) {:name}
      subject {builder.send method, attribute}
      before {resource.valid?}

      specify 'input has correct error class' do
        expect(subject).to have_tag("#person_#{attribute}_container.govuk-form-group--error") do |fge|
          expect(fge).to have_tag("#{element}.govuk-input--error")
        end
      end

      specify 'error message is displayed within the label' do
        expect(subject).to have_tag("#person_#{attribute}_container.govuk-form-group--error") do |fge|
          expect(fge).to have_tag('label', text: /Full name/, with: {for: "person_#{attribute}"}) do |label|
            expect(label).to have_tag('span', text: 'Full name is required')
          end
        end
      end

      context 'custom translations' do

        let(:custom_translations) do
          YAML.load(
            <<~TRANSLATION
              errors:
                format: "%{message}"
              activemodel:
                errors:
                  models:
                    person:
                      attributes:
                        name:
                          blank: "Enter your full name"
            TRANSLATION
          )
        end

        let(:message) {I18n.t('activemodel.errors.models.person.attributes.name.blank')}

        specify 'should use the appropriate error messages as defined by the translation' do
          with_translations(:en, custom_translations) do

            # we need to validate the resource *after* having
            # loaded the translationsk, so it can't be done in
            # a before block
            resource.valid?

            expect(builder.send(method, attribute)).to have_tag("#person_#{attribute}_container.govuk-form-group--error") do |fge|
              expect(fge).to have_tag('span', text: message)
            end

          end
        end
      end

      context 'nested objects (fields_for)' do
        context 'nested once' do
          let(:address) {Address.new.tap{|a| a.valid?}}

          subject do
            builder.fields_for(:address) do |a|
              a.send(method, :postcode)
            end
          end

          before {resource.address = address}

          specify 'error message should be in label-contained span' do
            expect(subject).to have_tag('label', text: 'Postcode is required', with: {
              for: 'person_address_attributes_postcode'
            })
          end

          specify 'input should have error attributes' do
            expect(subject).to have_tag(element, with: {
              name: "person[address_attributes][postcode]"
            })
          end
        end

        context 'nested twice' do
          let(:country) {Country.new.tap{|c| c.valid?}}
          let(:resource_address) do
            Address.new.tap do |address|
              address.country = country
              address.country.valid?
            end
          end

          subject do
            builder.fields_for(:address) do |address|
              address.fields_for(:country) do |country|
                country.send method, :name
              end
            end
          end

          before {resource.address = resource_address}

          specify 'outputs error message label-contained span' do
            expect(subject).to have_tag('label', text: 'Country is required', with: {
              for: 'person_address_attributes_country_attributes_name'
            })
          end

          specify 'input should have error attributes' do
            expect(subject).to have_tag(element, with: {
              name: "person[address_attributes][country_attributes][name]"
            })
          end
        end
      end

    end

  end

  describe '#text_field' do
    include_examples 'input field', :text_field, :text
  end

  describe '#text_area' do
    include_examples 'input field', :text_area, nil
  end

  describe '#email_field' do
    include_examples 'input field', :email_field, :email
  end

  describe "#number_field" do
    include_examples 'input field', :number_field, :number
  end

  describe '#password_field' do
    include_examples 'input field', :password_field, :password
  end

  describe '#phone_field' do
    include_examples 'input field', :phone_field, :tel
  end

  describe '#range_field' do
    include_examples 'input field', :range_field, :range
  end

  describe '#search_field' do
    include_examples 'input field', :search_field, :search
  end

  describe '#telephone_field' do
    include_examples 'input field', :telephone_field, :tel
  end

  describe '#url_field' do
    include_examples 'input field', :url_field, :url
  end

  describe '#radio_button_fieldset' do

    context 'outputs radio buttons in a stacked layout' do
      let(:locations) {[:ni, :isle_of_man_channel_islands, :british_abroad]}
      subject {builder.radio_button_fieldset :location, choices: locations}

      specify 'outputs a form group containing the correct number of radio buttons' do
        expect(subject).to have_tag("div.govuk-form-group")
      end

      specify 'includes the appropriate hint in the form' do
        expect(subject).to have_tag("span.govuk-hint", text: I18n.t('helpers.hint.person.location'))
      end

      specify 'radio buttons exist for each of the relevant options' do
        locations.each do |location|
          attributes = {type: 'radio', name: 'person[location]'}
          selector = "input#person_location_#{location}"
          expect(subject).to have_tag(selector, with: attributes)
        end
      end

      specify 'each radio button should have an appropriate label' do

        # :other isn't specified in :locations so won't appear, don't
        # check for it
        I18n
          .t('helpers.label.person.location')
          .reject{|k,v| k == :other}
          .each do |k,v|
            attributes = {for: "person_location_#{k}"}
            expect(subject).to have_tag('label', with: attributes, text: v)
          end

      end

    end

    context 'when no choices specified' do

      subject {builder.radio_button_fieldset(:has_user_account)}

      specify 'outputs yes/no choices' do
        expect(subject).to have_tag('.govuk-form-group > fieldset') do |fieldset|
          expect(fieldset).to have_tag('div', with: { class: 'govuk-radios', 'data-module' => 'govuk-radios' }) do |radios|
            expect(radios).to have_tag('div.govuk-radios__item > input', count: 2, with: {type: 'radio'})
            expect(radios).to have_tag('input', with: {value: 'no'})
            expect(radios).to have_tag('input', with: {value: 'yes'})
          end
        end
      end

      specify 'yes/no choices have labels' do
        expect(subject).to have_tag('.govuk-form-group > fieldset') do |fieldset|
          expect(fieldset).to have_tag('label', text: 'Yes', with: {for: 'person_has_user_account_yes'})
          expect(fieldset).to have_tag('label', text: 'No', with: {for: 'person_has_user_account_no'})
        end
      end

    end

    context 'adds inline class to fieldset when inline option passed' do
      subject {builder.radio_button_fieldset(:has_user_account, inline: true)}

      specify "fieldset should have 'inline' class" do
        expect(subject).to have_tag('.govuk-form-group > fieldset.inline')
      end
    end

    context 'revealing panels' do

      let(:other_input) {:location_other}
      let(:other_input_panel) {:location_other_panel}
      let(:other_input_label) { I18n.t('label.location_other') }

      let(:hidden_classes) {".govuk-radios__conditional.govuk-radios__conditional--hidden"}

      subject do
        builder.radio_button_fieldset(:location) do |fieldset|
          fieldset.radio_input(:england)
          fieldset.radio_input(:other) {
            fieldset.text_field other_input
          }
        end
      end

      specify "there should be an 'other' entry" do
        expect(subject).to have_tag('.govuk-radios__item') do
          expect(subject).to have_tag('input', with: {
            type: 'radio',
            value: 'other',
            'data-aria-controls' => other_input_panel
          })
        end
      end

      specify "there should be a hidden panel for the 'other' entry" do
        expect(subject).to have_tag(hidden_classes, with: {id: other_input_panel})
      end

      specify 'the hidden panel should contain a text input' do
        expect(subject).to have_tag(hidden_classes) do |panel|
          expect(panel).to have_tag('input.govuk-input', with: {
            type: 'text',
            name: "person[#{other_input}]"
          })
        end
      end

      specify "the hidden 'other' input should be labelled correctly" do
        expect(subject).to have_tag(hidden_classes) do |panel|
          expect(panel).to have_tag('label.govuk-label', with: {
            for: "person_#{other_input}"
          })
        end
      end
    end

    context 'revealing panels with a specific id' do

      let(:other_input) {:location_other}
      let(:custom_div) {"a-customisable-div"}

      subject do
        builder.radio_button_fieldset :location do |fieldset|
          fieldset.radio_input(:england)
          fieldset.radio_input(:other, panel_id: custom_div) do
            fieldset.text_field other_input
          end
        end
      end

      specify 'outputs markup with support for revealing panels with specific id' do
        expect(subject).to have_tag('.govuk-radios__input', with: {"data-aria-controls" => custom_div})
      end

    end

    context 'legend options' do
      let(:custom_class) {"bright-pink"}
      let(:language) {"en"}

      subject do
        builder.radio_button_fieldset :has_user_account, inline: true, legend_options: {class: custom_class, lang: language}
      end

      specify 'should be propagated down to the inner legend when provided' do
        expect(subject).to have_tag("legend > h2.govuk-fieldset__heading.#{custom_class}", with: {lang: language})
      end

    end

    context 'custom names and values' do

      let(:cases) {[ Case.new(id: 18, name: 'Case One'), Case.new(id: 19, name: 'Case Two')]}
      subject {builder.radio_button_fieldset(:case_id, choices: cases, value_method: :id, text_method: :name)}

      specify 'name and value should match provided options' do
        cases.each do |kase|

          expect(subject).to have_tag("input#person_case_id_#{kase.id}", with: {
            value: kase.id,
            type: 'radio'
          })

          expect(subject).to have_tag('label', text: kase.name, with: {
            for: "person_case_id_#{kase.id}"
          })

        end
      end

    end

    context 'when the resource is invalid' do
      let(:resource) {Person.new}
      let(:error_message) {"Gender is required"}
      subject {builder.radio_button_fieldset :gender}

      before do
        resource.valid?
      end

      specify 'the form group should have error classes' do
        expect(subject).to have_tag('.govuk-form-group.govuk-form-group--error')
      end

      specify 'the form group should have error messages' do
        expect(subject).to have_tag('.govuk-form-group--error span.govuk-error-message', text: error_message)
      end

    end

  end

  describe '#check_box_fieldset' do
    before {resource.waste_transport = WasteTransport.new}

    let(:waste_categories) {[:animal_carcasses, :mines_quarries, :farm_agricultural]}
    subject do
      builder.fields_for(:waste_transport) {|f| f.check_box_fieldset(:waste_transport, waste_categories)}
    end

    specify 'fieldset has the correct heading' do
      text = I18n.t('helpers.fieldset.person[waste_transport_attributes].waste_transport')
      expect(subject).to have_tag('fieldset legend > h2.govuk-fieldset__heading', text)
    end

    specify 'outputs checkboxes with labels' do
      expect(subject).to have_tag('div.govuk-form-group') do |form_group|
        expect(form_group).to have_tag('input', with: {type: 'checkbox'}, count: waste_categories.size)
        expect(form_group).to have_tag('label', count: waste_categories.size)
      end
    end

    specify 'checkboxes have correct attributes' do

      waste_categories.each do |wc|

        selector = ['person', 'waste_transport_attributes', wc].join('_')

        expect(subject).to have_tag(
          "input##{selector}",
          with: {
            type: 'checkbox',
            name: "person[waste_transport_attributes][#{wc}]"
          }
        )

      end
    end

    specify 'labels have correct content' do
      I18n.t('helpers.label.person[waste_transport_attributes]').each do |k,v|

        # this isn't straightforward because Rails's I18n allows for HTML snippets
        # to be added to the translations, so we need to strip the `_html` suffix
        # from the key and parse the HTML to extract only the text.
        target = "person_waste_transport_attributes_#{k}".gsub(/_html$/, "")
        text = Nokogiri::HTML(v).text

        expect(subject).to have_tag('label', with: {for: target}, text: text)
      end
    end


    context 'revealing panels' do

      subject do
        builder.fields_for(:waste_transport) do |f|
          f.check_box_fieldset :waste_transport, [:animal_carcasses, :mines_quarries, :farm_agricultural] do |fieldset|

            # FIXME I'm not sure why the fieldset.safe_join is required here,
            # in the actual formbuilder on the sample site the following layout
            # works fine with erb but in the tests only the last
            # check_box_input is returned.

            fieldset.safe_join([
              fieldset.check_box_input(:animal_carcasses),
              fieldset.check_box_input(:mines_quarries) { f.text_field :mines_quarries_details },
              fieldset.check_box_input(:farm_agricultural) { f.text_field :farm_agricultural_details }
            ])
          end
        end
      end

      let(:fields_with_hidden_panels) {[:mines_quarries, :farm_agricultural]}
      let(:field_without_hidden_panel) {:animal_carcasses}
      let(:hidden_classes) {".govuk-checkboxes__conditional.govuk-checkboxes__conditional--hidden"}

      specify 'inputs are marked as multiple choice' do
        count = fields_with_hidden_panels.push(field_without_hidden_panel).size
        expect(subject).to have_tag('div.govuk-checkboxes__item', count: count)
      end

      specify 'should not add a text field to checkboxes without associated text fields' do
        expect(subject).not_to have_tag("div##{field_without_hidden_panel}_panel")
      end

      specify 'should add a text field to checkboxes with associated text fields' do
        fields_with_hidden_panels.each do |fwhp|
          expect(subject).to have_tag("div##{fwhp}_panel") do |panel|

            attributes = {
              type: 'text',
              name: "person[waste_transport_attributes][#{fwhp}_details]"
            }

            expect(panel).to have_tag("#{hidden_classes} input", with: attributes)
          end
        end

      end

      context 'with a specific ID' do
        let(:waste_transport) {WasteTransport.new}
        before {resource.waste_transport = waste_transport}

        subject do
          builder.fields_for(:waste_transport) do |f|
            f.check_box_fieldset :waste_transport, [:animal_carcasses, :mines_quarries] do |fieldset|
              fieldset.check_box_input(:animal_carcasses)
              fieldset.check_box_input(:mines_quarries, panel_id: 'mines_quarries_details_text_field_input')
            end
          end
        end

        specify 'outputs markup with support for revealing panels with specific ID' do

          expect(subject).to have_tag('div.govuk-checkboxes__item') do
            expect(subject).to have_tag("input.govuk-checkboxes__input", with: {
              'data-aria-controls' => 'mines_quarries_details_text_field_input'
            })
          end

        end
      end
    end
  end

  describe '#collection_radio_buttons' do

    let(:input_type) {'radio'}
    let(:person) {Person.new}
    let(:gender_collection) {
      [
        OpenStruct.new(code: 'M', name: 'Masculine'),
        OpenStruct.new(code: 'F', name: 'Feminine'),
        OpenStruct.new(code: 'N', name: 'Neuter')
      ]
    }

    subject {
      builder.capture do
        builder.collection_radio_buttons :gender, gender_collection, :code, :name, {id: 'gender-radio-id'}
      end
    }

    let(:input_container) {'div.govuk-form-group > fieldset > .govuk-radios > .govuk-radios__item'}

    specify 'builds the legend, form label and hint correctly' do
      expect(subject).to have_tag('div.govuk-form-group > fieldset > legend') do |legend|
        expect(legend).to have_tag('span.govuk-label', text: 'Gender')
        expect(legend).to have_tag('span.govuk-hint', text: 'Select from these options')
      end
    end

    specify 'adds the correct number of radio buttons' do
      expect(subject).to have_tag(input_container, count: gender_collection.size)
    end

    specify 'correctly builds the entries' do
      gender_collection.each do |gc|
        attributes = {type: input_type, value: gc.code, name: "person[gender]"}
        expect(subject).to have_tag("#{input_container} > input#person_gender_#{gc.code.downcase}", with: attributes)
      end
    end

    specify 'correctly labels each radio button' do
      gender_collection.each do |gc|
        attributes = {for: "person_gender_#{gc.code.downcase}"}
        expect(subject).to have_tag("#{input_container} > label", text: gc.name, with: attributes)
      end
    end

  end

  describe '#collection_check_boxes' do

    let(:input_type) {'checkbox'}
    let(:person) {Person.new}
    let(:gender_collection) {
      [
        OpenStruct.new(code: 'M', name: 'Masculine'),
        OpenStruct.new(code: 'F', name: 'Feminine'),
        OpenStruct.new(code: 'N', name: 'Neuter')
      ]
    }

    subject {
      builder.collection_check_boxes :gender, gender_collection, :code, :name, {id: 'gender-radio-id'}
    }

    let(:input_container) {'div.govuk-form-group > fieldset > .govuk-checkboxes > .govuk-checkboxes__item'}

    specify 'builds the legend, form label and hint correctly' do
      expect(subject).to have_tag('div.govuk-form-group > fieldset > legend') do |legend|
        expect(legend).to have_tag('span.govuk-label', text: 'Gender')
        expect(legend).to have_tag('span.govuk-hint', text: 'Select from these options')
      end
    end

    specify 'adds the correct number of check boxes' do
      expect(subject).to have_tag(input_container, count: gender_collection.size)
    end

    specify 'correctly builds the entries' do
      gender_collection.each do |gc|
        attributes = {type: input_type, value: gc.code, name: "person[gender][]"}
        expect(subject).to have_tag("#{input_container} > input#person_gender_#{gc.code.downcase}", with: attributes)
      end
    end

    specify 'correctly labels each check box' do
      gender_collection.each do |gc|
        attributes = {for: "person_gender_#{gc.code.downcase}"}
        expect(subject).to have_tag("#{input_container} > label", text: gc.name, with: attributes)
      end
    end

  end


  describe '#collection_select' do

    let(:genders) {[:male, :female]}

    context 'select element and labels' do

      subject {builder.collection_select(:gender, genders, :to_s, :to_s)}

      specify 'outputs a div containing select and label elements' do

        expect(subject).to have_tag('div.govuk-form-group') do |div|
          expect(div).to have_tag('label.govuk-label')
          expect(div).to have_tag('select.govuk-select')
        end

      end

      specify 'the label has the correct text and attributes' do
        selector = 'div.govuk-form-group > label.govuk-label'
        expect(subject).to have_tag(selector, text: /Gender/, options: {for: 'person_gender'})
      end

      specify 'the select box has the correct contents' do
        selector = 'div.govuk-form-group > select#person_gender.govuk-select'
        attributes = {name: 'person[gender]'}

        expect(subject).to have_tag(selector, with: attributes) do |select|
          genders.each do |gender|
            expect(select).to have_tag('option', with: {value: gender}, text: gender)
          end
        end

      end
    end

    context 'outputs select lists with labels and hints' do
      let(:locations) {[:ni, :isle_of_man_channel_islands]}
      let(:hint) {I18n.t('helpers.hint.person.location')}

      subject {builder.collection_select(:location, locations, :to_s, :to_s, {})}

      specify 'should display the correct hints if they are defined' do
        selector = 'div.govuk-form-group > label.govuk-label'
        expect(subject).to have_tag(selector, text: hint, options: {for: 'person_location'})
      end

    end

    context 'custom classes' do
      let(:custom_class) {"my-custom-style"}
      subject {builder.collection_select :gender, genders, :to_s, :to_s, {}, class: custom_class}

      specify 'it should add a custom class when one is supplied' do
        expect(subject).to have_tag("select.#{custom_class}")
      end

    end

    context 'blanks' do
      let(:blank_text) {"Please select an option"}
      subject {builder.collection_select :gender, genders, :to_s, :to_s, {include_blank: blank_text}}

      specify 'it should add a insert a blank entry when include_blank is supplied' do
        expect(subject).to have_tag("select > option", text: blank_text, with: {value: ""})
      end
    end

  end

  describe '#date_field' do
    subject {builder.date_field(:created_at)}
    let(:label_text) {"Created at"}

    specify 'should create a fieldset containing legend and inputs' do
      expect(subject).to have_tag('fieldset > legend')
      expect(subject).to have_tag('input', count: 3)
    end

    specify 'legend should have the correct title' do
      expect(subject).to have_tag('fieldset > legend') do |legend|
        expect(legend).to have_tag('span', class: %w{govuk-label}, text: label_text)
      end
    end

    context 'labels and inputs' do
      {day: '3i', month: '2i', year: '1i'}.each do |segment, identifier|

        context "#{segment.capitalize}" do
          specify "should have a #{segment} label" do
            expect(subject).to have_tag('label', text: segment.capitalize)
          end

          specify "should have a #{segment} input" do
            expect(subject).to have_tag('input', with: {
              name: "person[created_at(#{identifier})]",
              type: 'number',
              pattern: '[0-9]*'
            })
          end
        end
      end
    end

    context 'autocompletion' do
      subject {builder.date_field(:created_at, date_of_birth: true)}

      specify "day should have autocomplete value of 'bday bday-day'" do
        expect(subject).to have_tag(
          'input',
          with: {
            id: 'person_created_at_3i',
            autocomplete: 'bday bday-day'
          }
        )
      end

      specify "month should have autocomplete value of 'bday bday-month'" do
        expect(subject).to have_tag(
          'input',
          with: {
            id: 'person_created_at_2i',
            autocomplete: 'bday bday-month'
          }
        )
      end

      specify "year should have autocomplete value of 'bday bday-year'" do
        expect(subject).to have_tag(
          'input',
          with: {
            id: 'person_created_at_1i',
            autocomplete: 'bday bday-year'
          }
        )
      end
    end

    context 'readonly' do
      subject {builder.date_field(:created_at, readonly: true)}

      specify "day should have readonly attribute" do
        expect(subject).to have_tag(
          'input',
          with: {
            id: 'person_created_at_3i',
            readonly: 'readonly'
          }
        )
      end

      specify "month should have readonly attribute" do
        expect(subject).to have_tag(
          'input',
          with: {
            id: 'person_created_at_2i',
            readonly: 'readonly'
          }
        )
      end

      specify "year should have readonly attribute" do
        expect(subject).to have_tag(
          'input',
          with: {
            id: 'person_created_at_1i',
            readonly: 'readonly'
          }
        )
      end
    end

    context 'disabled' do
      subject {builder.date_field(:created_at, disabled: true)}

      specify "day should have disabled attribute" do
        expect(subject).to have_tag(
          'input',
          with: {
            id: 'person_created_at_3i',
            disabled: 'disabled'
          }
        )
      end

      specify "month should have disabled attribute" do
        expect(subject).to have_tag(
          'input',
          with: {
            id: 'person_created_at_2i',
            disabled: 'disabled'
          }
        )
      end

      specify "year should have disabled attribute" do
        expect(subject).to have_tag(
          'input',
          with: {
            id: 'person_created_at_1i',
            disabled: 'disabled'
          }
        )
      end
    end
  end

  describe '#submit' do
    subject {builder.submit("Enter")}

    specify "outputs an input tag with the correct classes" do
      expect(subject).to have_tag('input', with: {
        class: 'govuk-button',
        type: 'submit',
        'data-module': 'govuk-button'
      })
    end

  end

  describe '#text_area_with_maxwords' do
    let :word_count do
      45
    end

    subject do
      builder.text_area_with_maxwords \
        :waste_transport,
        maxwords: { count: word_count }
    end

    specify "outputs a textarea with correct data_attributes" do
      expect(subject).to have_tag 'div', with: { class: %w(govuk-character-count), 'data-module' => "govuk-character-count", 'data-maxwords' => word_count } do
        with_tag \
          'textarea',
          with: {
            name: 'person[waste_transport]',
            class: 'govuk-js-character-count'
          }
      end
    end
  end
end
