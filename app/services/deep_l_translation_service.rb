require "net/https"
require "net/http"
require "uri"
require "json"

class DeepLTranslationService
  def self.auto_translate_with_deepl(record)
    @record = record
    @translated_record = find_translated_record
    @source_language = @translated_record.locale

    @translate_arguments = extract_translate_arguments
    missing_translations = find_missing_translations
    translations_to_update = find_translations_to_update
    translation = perform_translations(missing_translations,
                                       translations_to_update)
    translation
  end

  private

    def self.find_translated_record
      find_translation_not_matching_regex ||
        @record.translations.first
    end

    def self.find_translation_not_matching_regex
      I18n.available_locales.each do |locale|
        translation = @record.translations.find_by(locale: locale)
        return translation unless is_automatically_translated?(locale)
      end
      nil
    end

    def self.extract_translate_arguments
      translated_attribute_names.map { |attr| [attr, @translated_record[attr]] }.to_h
    end

    def self.perform_translations(missing_translations, translations_to_update)
      translation = {}

      (missing_translations + translations_to_update).each do |locale|
        if locale == :de
          pp "translate_arguments", @translate_arguments
          pp "locale", locale
        end
        translation = translate_with_deepl(@translate_arguments, locale)
        if translation.present?
          pp "is_automatically_translated", is_automatically_translated?(locale)
          if is_automatically_translated?(locale)
            update_translation(locale, translation)
          else
            save_translation(locale, translation)
          end
        end
      end

      translation
    end

    def self.get_new_translation_arguments
      @translate_arguments.keys.each_with_object({}) do |key, hash|
        hash[key] = @record.send(key)
      end
    end

    def self.translate_with_deepl(texts, target_lang)
      deepl_api_key = Tenant.current_secrets.deepl_api_key

      texts.transform_values! { |value| remove_translation_hint(value) }
      uri = URI("https://api-free.deepl.com/v2/translate")

      header = { 'Content-Type': "application/json", "Authorization" => "DeepL-Auth-Key #{deepl_api_key}" }
      body = { text: texts.values,
               source_lang: locale_to_upcase_string(@source_language),
               target_lang: locale_to_upcase_string(target_lang) }.to_json

      response = Net::HTTP.post(uri, body, header)

      return unless response.is_a?(Net::HTTPSuccess)

      parsed_response = JSON.parse(response.body)
      build_translation_result(texts, parsed_response, target_lang)
    end

    def self.build_translation_result(texts, parsed_response, target_lang)
      result = {}
      texts.each_with_index do |(key, _), index|
        translated_text = parsed_response["translations"][index]["text"]
        result[key] = add_translation_hint(translated_text, target_lang)
      end
      result
    end

    def self.locale_to_upcase_string(language)
      language.to_s.slice(0, 2).upcase
    end

    def self.add_translation_hint(text, locale)
      text.empty? || text.match?(/^\[.+?\]\s*/) ? text : "[automatically translated] " + text
    end

    def self.remove_translation_hint(text)
      text.sub(/^\[.+?\]\s*/, "")
    end

    def self.is_automatically_translated?(locale)
      translation = @record.translations.find_by(locale: locale)
      translation&.attributes&.any? { |_, value| value.is_a?(String) && value.match?(/^\[.+?\]\s*/) }
    end

    def self.find_missing_translations
      I18n.available_locales.reject { |locale| @record.translations.exists?(locale: locale) }
    end

    def self.find_translations_to_update
      I18n.available_locales.select do |locale|
        is_automatically_translated?(locale)
      end
    end

    def self.translated_attribute_names
      excluded_columns = ["id", "locale", "created_at", "updated_at", "hidden_at",
                          "#{@record.class.name.underscore.gsub("/", "_")}_id"]
      @record.translations.map(&:attributes).map(&:keys).flatten.uniq - excluded_columns
    end

    def self.save_translation(locale, translation)
      new_translation = @record.translations.build(locale: locale)
      translation.each { |key, value| new_translation[key] = value }
      new_translation.save!
    end

    def self.update_translation(locale, new_translation)
      if(locale == :en)
        pp "@record.translations.find_by(locale: locale)", @record.translations.find_by(locale: locale)
        pp "new_trans", new_translation
      end
      @record.translations.find_by(locale: locale)&.update!(new_translation)
    end
end
