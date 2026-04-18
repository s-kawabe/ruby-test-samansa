if Rails.env.development?
  Rails.application.config.after_initialize do
    if ActiveRecord::Base.connection.table_exists?(:plans)
      load Rails.root.join("db/seeds.rb")
    end
  end
end
