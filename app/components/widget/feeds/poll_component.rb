class Widget::Feeds::PollComponent < ApplicationComponent
  attr_reader :poll

  def initialize(poll)
    @poll = poll
  end
end
