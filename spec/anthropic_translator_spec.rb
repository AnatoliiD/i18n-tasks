# frozen_string_literal: true

require "spec_helper"
require "i18n/tasks/commands"
require "i18n/tasks/translators/anthropic_translator"
require "anthropic"

RSpec.describe "Anthropic Translation" do
  nil_value_test = ["nil-value-key", nil, nil]
  empty_value_test = ["empty-value-key", "", ""]
  text_test = ["hello", "Hello, %{user} O'Neill!", "¡Hola, %{user} O'Neill!"]
  text_test_multiline = [
    "hello_multiline",
    "Hello,\n%{user}\nO'Neill!",
    "¡Hola,\n%{user}\nO'Neill!"
  ]
  html_test = ["html-key.html", "Hello, <b>%{user} O'neill</b>", "Hola, <b>%{user} O'neill</b>"]
  html_test_plrl = ["html-key.html.one", "<b>Hello %{count}</b>", "<b>Hola %{count}</b>"]
  html_test_multiline = [
    "html-key.html.multiline_html",
    "<b>Hello</b>\n<b>%{user}</b>",
    "<b>Hola</b>\n<b>%{user}</b>"
  ]
  array_test = ["array-key", ["Hello.", nil, "", "Goodbye."], ["Hola.", nil, "", "Adiós."]]
  fixnum_test = ["numeric-key", 1, 1]
  ref_key_test = ["ref-key", :reference, :reference]

  delegate :i18n_task, :in_test_app_dir, :run_cmd, to: :TestCodebase
  let(:task) { i18n_task }

  def stub_anthropic_response(translations)
    text_block = instance_double(Anthropic::Models::TextBlock, text: {"translations" => translations}.to_json)
    instance_double(Anthropic::Models::Message, content: [text_block])
  end

  before do
    TestCodebase.setup("config/locales/en.yml" => "", "config/locales/es.yml" => "")
  end

  after do
    TestCodebase.teardown
  end

  describe "real world test" do
    it "translates all missing keys" do
      skip "ANTHROPIC_API_KEY env var not set" unless ENV["ANTHROPIC_API_KEY"]
      skip "ANTHROPIC_API_KEY env var is empty" if ENV["ANTHROPIC_API_KEY"].empty?
      in_test_app_dir do
        task.data[:en] = build_tree(
          "en" => {
            "common" => {
              "a" => "λ",
              "hello" => text_test[1],
              "hello_multiline" => text_test_multiline[1],
              "hello_html" => html_test[1],
              "hello_plural_html" => {
                "one" => html_test_plrl[1]
              },
              "hello_multiline_html" => html_test_multiline[1],
              "array_key" => array_test[1],
              "nil-value-key" => nil_value_test[1],
              "empty-value-key" => empty_value_test[1],
              "fixnum-key" => fixnum_test[1],
              "ref-key" => ref_key_test[1]
            }
          }
        )
        task.data[:es] = build_tree("es" => {
          "common" => {
            "a" => "λ"
          }
        })

        run_cmd "translate-missing", "--backend=anthropic"
        expect(task.t("common.hello", "es")).to eq(text_test[2])
        expect(task.t("common.hello_multiline", "es")).to eq(text_test_multiline[2])
        expect(task.t("common.hello_html", "es")).to eq(html_test[2])
        expect(task.t("common.hello_plural_html.one", "es")).to eq(html_test_plrl[2])
        expect(task.t("common.hello_multiline_html", "es")).to eq(html_test_multiline[2])
        expect(task.t("common.array_key", "es")).to eq(array_test[2])
        expect(task.t("common.nil-value-key", "es")).to eq(nil_value_test[2])
        expect(task.t("common.empty-value-key", "es")).to eq(empty_value_test[2])
        expect(task.t("common.fixnum-key", "es")).to eq(fixnum_test[2])
        expect(task.t("common.ref-key", "es")).to eq(ref_key_test[2])
        expect(task.t("common.a", "es")).to eq("λ")
      end
    end
  end

  describe "stubbed test" do
    around do |example|
      original_value = ENV.fetch("ANTHROPIC_API_KEY", nil)
      ENV["ANTHROPIC_API_KEY"] = "stubbed_value"
      example.run
      ENV["ANTHROPIC_API_KEY"] = original_value
    end

    context "when translating to spanish" do
      it "translates missing" do
        client = instance_double(Anthropic::Client)
        messages = instance_double(Anthropic::Resources::Messages)
        allow(Anthropic::Client).to receive(:new).and_return(client)
        allow(client).to receive(:messages).and_return(messages)

        allow(messages).to receive(:create).with(
          hash_including(
            model: "claude-haiku-4-5",
            max_tokens: 4096,
            temperature: 0.0,
            system: a_string_including(
              "translates content from the English locale to the Spanish locale in an i18n locale array"
            ),
            messages: array_including(
              hash_including(
                role: "user",
                content: a_string_including("Hello, X__0 O'Neill!")
              )
            )
          )
        ).and_return(stub_anthropic_response(["¡Hola, X__0 O'Neill!"]))

        in_test_app_dir do
          task.data[:en] = build_tree(
            "en" => {
              "common" => {
                "hello" => "Hello, %{user} O'Neill!"
              }
            }
          )
          task.data[:es] = build_tree("es" => {"placeholder" => "need something here"})
          run_cmd "translate-missing", "--backend=anthropic", "--locales=es"

          expect(task.t("common.hello", "es")).to eq("¡Hola, %{user} O'Neill!")
        end
      end
    end

    context "when translating to ukrainian" do
      before do
        TestCodebase.setup("config/locales/en.yml" => "", "config/locales/uk.yml" => "")
      end

      it "translates missing" do
        client = instance_double(Anthropic::Client)
        messages = instance_double(Anthropic::Resources::Messages)
        allow(Anthropic::Client).to receive(:new).and_return(client)
        allow(client).to receive(:messages).and_return(messages)

        allow(messages).to receive(:create).with(
          hash_including(
            model: "claude-haiku-4-5",
            max_tokens: 4096,
            temperature: 0.0,
            system: a_string_including("translates content from the English locale to the Ukrainian locale"),
            messages: array_including(
              hash_including(
                role: "user",
                content: a_string_including("Hello, X__0 O'Neill!")
              )
            )
          )
        ).and_return(stub_anthropic_response(["Привіт, X__0 O'Neill!"]))

        in_test_app_dir do
          task.data[:en] = build_tree(
            "en" => {
              "common" => {
                "hello" => "Hello, %{user} O'Neill!"
              }
            }
          )
          task.data[:uk] = build_tree("uk" => {"placeholder" => "need something here"})
          run_cmd "translate-missing", "--backend=anthropic", "--locales=uk"

          expect(task.t("common.hello", "uk")).to eq("Привіт, %{user} O'Neill!")
        end
      end
    end

    context "when network error interrupts mid-translation" do
      it "writes only successfully translated keys, skipping failed batch" do
        client = instance_double(Anthropic::Client)
        messages = instance_double(Anthropic::Resources::Messages)
        allow(Anthropic::Client).to receive(:new).and_return(client)
        allow(client).to receive(:messages).and_return(messages)

        batch1_translations = (1..50).map { |i| "es#{i.to_s.rjust(2, "0")}" }
        call_count = 0
        allow(messages).to receive(:create) do
          call_count += 1
          if call_count == 1
            stub_anthropic_response(batch1_translations)
          else
            raise StandardError, "simulated network error"
          end
        end

        in_test_app_dir do
          en_keys = (1..51).each_with_object({}) do |i, h|
            h["k#{i.to_s.rjust(2, "0")}"] = "v#{i.to_s.rjust(2, "0")}"
          end
          task.data[:en] = build_tree("en" => {"common" => en_keys})
          task.data[:es] = build_tree("es" => {"placeholder" => "need something here"})
          run_cmd "translate-missing", "--backend=anthropic", "--locales=es"

          es_keys = task.data[:es].leaves.map(&:full_key)
          expect(es_keys).to include("es.common.k01")
          expect(es_keys).to include("es.common.k50")
          expect(es_keys).not_to include("es.common.k51")
          expect(task.t("common.k01", "es")).to eq("es01")
        end
      end
    end

    context "when using per-locale prompts" do
      before do
        TestCodebase.setup(
          "config/locales/en.yml" => "",
          "config/locales/es.yml" => "",
          "config/i18n-tasks.yml" => {
            translation: {
              backend: :anthropic,
              anthropic_api_key: "stubbed_value",
              anthropic_locale_prompts: {
                es: "Custom Spanish prompt for %{from} to %{to}: Use informal language and Mexican expressions."
              }
            }
          }.to_yaml
        )
      end

      it "uses locale-specific prompt for Spanish" do
        client = instance_double(Anthropic::Client)
        messages = instance_double(Anthropic::Resources::Messages)
        allow(Anthropic::Client).to receive(:new).and_return(client)
        allow(client).to receive(:messages).and_return(messages)

        allow(messages).to receive(:create).with(
          hash_including(
            model: "claude-haiku-4-5",
            max_tokens: 4096,
            temperature: 0.0,
            system: a_string_including(
              "Custom Spanish prompt for English to Spanish: Use informal language and Mexican expressions."
            )
          )
        ).and_return(stub_anthropic_response(["¡Órale, qué tal X__0!"]))

        in_test_app_dir do
          task.data[:en] = build_tree(
            "en" => {
              "common" => {
                "hello" => "Hello, %{user}!"
              }
            }
          )
          task.data[:es] = build_tree("es" => {"placeholder" => "need something here"})
          run_cmd "translate-missing", "--backend=anthropic", "--locales=es"

          expect(task.t("common.hello", "es")).to eq("¡Órale, qué tal %{user}!")
        end
      end

      it "falls back to default prompt for locales without custom prompts" do
        client = instance_double(Anthropic::Client)
        messages = instance_double(Anthropic::Resources::Messages)
        allow(Anthropic::Client).to receive(:new).and_return(client)
        allow(client).to receive(:messages).and_return(messages)

        allow(messages).to receive(:create).with(
          hash_including(
            model: "claude-haiku-4-5",
            max_tokens: 4096,
            temperature: 0.0,
            system: a_string_including(
              "You are a professional translator that translates content from the English locale to the French locale"
            )
          )
        ).and_return(stub_anthropic_response(["Bonjour, X__0!"]))

        TestCodebase.setup(
          "config/locales/en.yml" => "",
          "config/locales/fr.yml" => ""
        )

        in_test_app_dir do
          task.data[:en] = build_tree(
            "en" => {
              "common" => {
                "hello" => "Hello, %{user}!"
              }
            }
          )
          task.data[:fr] = build_tree("fr" => {"placeholder" => "need something here"})
          run_cmd "translate-missing", "--backend=anthropic", "--locales=fr"

          expect(task.t("common.hello", "fr")).to eq("Bonjour, %{user}!")
        end
      end
    end
  end
end
