class Comment
  include Mongoid::Document
  include Mongoid::Timestamps

  field :user_name, type: String
  field :user_avatar, type: String
  field :body, type: String

  validates :user_name, presence: true
  validates :user_avatar, presence: true
  validates :body, presence: true

  belongs_to :user
  embedded_in :album
end
