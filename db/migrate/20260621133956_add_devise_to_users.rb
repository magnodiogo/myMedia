# frozen_string_literal: true
require 'bcrypt'

class AddDeviseToUsers < ActiveRecord::Migration[7.1]
  def self.up
    # Ensure no email is nil
    execute("UPDATE users SET email = '' WHERE email IS NULL")

    change_table :users do |t|
      ## Database authenticatable
      # t.string :email,              null: false, default: "" # Already exists
      t.string :encrypted_password, null: false, default: ""

      ## Recoverable
      t.string   :reset_password_token
      t.datetime :reset_password_sent_at

      ## Rememberable
      t.datetime :remember_created_at
    end

    change_column_null :users, :email, false
    change_column_default :users, :email, ""

    # Set default password "password" for existing users using BCrypt directly
    # to avoid loading User model before validation/schema update is finished
    encrypted_password = BCrypt::Password.create('password')
    execute("UPDATE users SET encrypted_password = '#{encrypted_password}' WHERE encrypted_password IS NULL OR encrypted_password = ''")

    add_index :users, :email,                unique: true
    add_index :users, :reset_password_token, unique: true
  end

  def self.down
    remove_index :users, :email
    remove_index :users, :reset_password_token

    change_table :users do |t|
      t.remove :encrypted_password
      t.remove :reset_password_token
      t.remove :reset_password_sent_at
      t.remove :remember_created_at
    end

    change_column_null :users, :email, true
    change_column_default :users, :email, nil
  end
end
