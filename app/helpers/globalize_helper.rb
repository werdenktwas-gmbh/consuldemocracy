module GlobalizeHelper
  def enabled_locale?(resource, locale)
    return site_customization_enable_translation?(locale) if resource.blank?

    if resource.locales_not_marked_for_destruction.any?
      resource.locales_not_marked_for_destruction.include?(locale)
    elsif resource.locales_persisted_and_marked_for_destruction.any?
      locale == first_marked_for_destruction_translation(resource)
    else
      locale == I18n.locale
    end
  end

  def first_translation(resource)
    if resource.locales_not_marked_for_destruction.include? I18n.locale
      I18n.locale
    else
      resource.locales_not_marked_for_destruction.first
    end
  end

  def first_marked_for_destruction_translation(resource)
    if resource.locales_persisted_and_marked_for_destruction.include? I18n.locale
      I18n.locale
    else
      resource.locales_persisted_and_marked_for_destruction.first
    end
  end

  def translations_for_locale?(resource)
    resource.locales_not_marked_for_destruction.any?
  end

  def selected_languages_description(resource)
    sanitize(t("shared.translations.languages_in_use", count: active_languages_count(resource)))
  end

  def remote_deepl_translation?
    Setting["feature.remote_deepl_translations"].presence
  end

  def select_language_error(resource)
    return if resource.blank?

    current_translation = resource.translation_for(selected_locale(resource))
    if current_translation.errors.added? :base, :translations_too_short
      tag.div class: "small error" do
        current_translation.errors[:base].join(", ")
      end
    end
  end

  def active_languages_count(resource)
    if resource.blank?
      no_resource_languages_count
    elsif resource.locales_not_marked_for_destruction.size > 0
      resource.locales_not_marked_for_destruction.size
    else
      1
    end
  end

  def no_resource_languages_count
    count = I18nContentTranslation.existing_languages.count
    count > 0 ? count : 1
  end

  def display_translation_style(resource, locale)
    "display: none;" unless display_translation?(resource, locale)
  end

  def display_translation?(resource, locale)
    return locale == I18n.locale if resource.blank?

    if resource.locales_not_marked_for_destruction.any?
      locale == first_translation(resource)
    elsif resource.locales_persisted_and_marked_for_destruction.any?
      locale == first_marked_for_destruction_translation(resource)
    else
      locale == I18n.locale
    end
  end

  def globalize(locale, &)
    Globalize.with_locale(locale, &)
  end
end
