# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Base Translator" do
  let(:task) { I18n::Tasks::BaseTask.new }

  # Create a fake translator that raises for html slices
  let(:translator_class) do
    Class.new(I18n::Tasks::Translators::BaseTranslator) do
      def translate_values(list, **options)
        if options[:html]
          raise StandardError, "html translation failure"
        end

        # return translated values simply by appending `-es` for testing
        list.map { |v| "#{v}-es" }
      end

      def options_for_translate_values(from:, to:, **options)
        options.merge(from: from, to: to)
      end

      def options_for_html
        {html: true}
      end

      def options_for_plain
        {html: false}
      end

      def no_results_error_message
        "no results"
      end
    end
  end

  it "drops failed slice pairs so untranslated keys are not written" do
    translator = translator_class.new(task)

    list = [
      ["common.plain", "Hello"],
      ["common.html.html", "<b>Hi</b>"]
    ]

    result = translator.send(:translate_pairs, list, from: "en", to: "es")

    plain = result.assoc("common.plain")
    expect(plain).not_to be_nil
    expect(plain.last).to eq("Hello-es")

    # HTML slice raised — its pair should be omitted entirely so the key
    # remains "missing" for the next translate-missing run.
    expect(result.assoc("common.html.html")).to be_nil
  end

  it "drops pairs whose translate_values returned nil" do
    partial_class = Class.new(I18n::Tasks::Translators::BaseTranslator) do
      def translate_values(list, **_options)
        list.map { |v| (v == "Skip") ? nil : "#{v}-es" }
      end

      def options_for_translate_values(from:, to:, **options)
        options.merge(from: from, to: to)
      end

      def options_for_html
        {}
      end

      def options_for_plain
        {}
      end

      def no_results_error_message
        "no results"
      end
    end

    translator = partial_class.new(task)
    list = [
      ["common.a", "Keep"],
      ["common.b", "Skip"]
    ]

    result = translator.send(:translate_pairs, list, from: "en", to: "es")

    expect(result.assoc("common.a")&.last).to eq("Keep-es")
    expect(result.assoc("common.b")).to be_nil
  end
end
