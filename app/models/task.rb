class Task < ActiveRecord::Base
  has_many    :users, through: :user_tasks
  has_many    :user_tasks
  has_many    :categories, through: :task_categories
  has_many    :task_categories
  belongs_to  :owner, class_name: "User"
  validates_presence_of :name, :summary, :due_date
  # validates :pay, allow_blank: true, numericality: {greater_than: 0}
  validates :pay,
            numericality: { greater_than: 0 },
            allow_nil: true,
            allow_blank: true


  def self.not_posted(user)
    Task.where("owner_id = ? AND status = ?", user.id, "pending")
  end

  def self.posted_tasks(user)
    Task.where("owner_id = ?", user.id)
        .where("status = ? 
                OR status = ?
                OR status = ? 
                AND is_paid = ?
                AND paid = ?",
                "available", 
                "in progress",
                "completed",
                false,
                true)
  end

  def self.posted_not_paid(user)
    Task.where("owner_id = ?", user.id)
          .where("status = ? 
                  AND is_paid =?",
                   "completed",
                    false)
  end

  def self.past_posted_tasks(user)
    Task.where("owner_id = ?", user.id)
          .where("status = ?
                  AND paid = ? 
                  OR status = ?
                  OR status = ?
                  AND is_paid = ?
                  AND paid = ?",
                  "completed",
                  false,
                  "expired", 
                  "completed",
                  true,
                  true)
  end

  def in_progress
    self.update(status: "in progress")
  end

  has_many :accepted_users, -> { where "user_tasks.status = 'accept'"},
           through: :user_tasks,
           source: :user

  has_many :pending_users, -> { where "user_tasks.status = 'pending'"},
           through: :user_tasks,
           source: :user

  has_many :rejected_users, -> { where "user_tasks.status = 'reject'"},
           through: :user_tasks,
           source: :user


  def workers
    accepted_users
  end

  filterrific(
    :default_settings => { :sorted_by => 'created_at_desc' },
    :filter_names => [
      :search_query,
      :sorted_by,
      :with_category_ids,
      :with_due_date,
      :with_paid
    ]
  )
    scope :search_query, lambda { |query|
      return nil  if query.blank?
         terms = query.downcase.split(/\s+/)
         terms = terms.map { |e|
           (e.gsub('*', '%') + '%').gsub(/%+/, '%')
         }
         num_or_conditions = 2
         Task.where(
           terms.map {
             or_clauses = [
               "LOWER(tasks.name) LIKE ?",
               "LOWER(tasks.summary) LIKE ?" #need to figure out how to search through the whole summary string
             ].join(' OR ')
             "(#{ or_clauses })"
           }.join(' AND '),
           *terms.map { |e| [e] * num_or_conditions }.flatten
         )
    }
    scope :sorted_by, lambda { |sort_option|
      direction = (sort_option =~ /desc$/) ? 'desc' : 'asc'
         case sort_option.to_s
         when /^created_at_/
           order("tasks.created_at #{ direction }")
         when /^due_date_/
           order("tasks.due_date #{ direction }")
         when /^name_/
           order("LOWER(tasks.name) #{ direction }, LOWER(tasks.name) #{ direction }")
         else
           raise(ArgumentError, "Invalid sort option: #{ sort_option.inspect }")
         end
    }
    scope :with_category_ids, lambda { |category_ids|
      task_categories = TaskCategory.arel_table
      tasks = Task.arel_table
      where(
        TaskCategory \
          .where(task_categories[:task_id].eq(tasks[:id])) \
          .where(task_categories[:category_id].in([*category_ids].map(&:to_i))) \
          .exists
      )
    }

    scope :with_paid, lambda { |option|
      if option == "Paid"
        where(paid: true)
      elsif option == "Free"
        where(paid: false)
      else
        all
      end
    }

    scope :with_due_date, lambda { |ref_date|
      where('tasks.due_date >= ?', ref_date)
    }

    def self.options_for_sorted_by
      [
        ['Name (a-z)', 'name_asc'],
        ['Due Date (newest first)', 'created_at_desc'],
        ['Due Date (oldest first)', 'created_at_asc']
      ]
    end

    def self.options_for_paid
      [
        ['Free'],
        ['Paid']
      ]
    end
end
