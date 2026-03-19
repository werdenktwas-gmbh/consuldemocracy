class Layout::FooterComponent < ApplicationComponent; 
  private

    def wdw_repository_link
      external_link_to(t("layouts.footer.consul"), "https://github.com/wer-denkt-was/consuldemocracy")
    end

end

load Rails.root.join("app", "components", "layout", "footer_component.rb")