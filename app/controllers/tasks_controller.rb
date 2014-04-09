class TasksController < ApplicationController
  before_action :set_task, only: [:show, :edit, :destroy, :update]
  before_action :authenticate_user!, except: [:index, :show]

  def index
    @filterrific = Filterrific.new(
          Task,
          params[:filterrific] || session[:filterrific_students]
        )
    @tasks = Task.where(status: "available").filterrific_find(@filterrific)

    # Persist the current filter settings in the session as a plain old Hash.
    session[:filterrific_tasks] = @filterrific.to_hash
    respond_to do |format|
          format.html
          format.js
    end
  end

  def reset_filterrific
      session[:filterrific_tasks] = nil
      redirect_to action: :index
    end

  def new
    @task = Task.new
  end

  def create
    @task = Task.create(task_params)
    if @task.save
      @task.categories = params[:task][:categories].present? ? Category.find_all_by_id(params[:task][:categories]) : [ ]
      redirect_to task_path(@task), notice: "Yay! Your gig is posted!"
    else
      render :new
    end
  end

  def update
    if @task.update(task_params)
      @task.categories = params[:task][:categories].present? ? Category.find_all_by_id(params[:task][:categories]) : [ ]
      redirect_to task_path(@task)
    else
      render :edit
    end
  end

  def edit
  end

  def show
  end

  def destroy
    @task.destroy
    redirect_to tasks_path
  end

  private
  def set_task
    @task = Task.find(params[:id])
  end

  def task_params
    params.require(:task).permit(:name, :owner_id, :paid, :pay, :status, :summary, :due_date, :due_time, :num_workers)
  end
end
