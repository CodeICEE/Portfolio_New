class ProjectsController < ApplicationController
  # NOTE: this action used to be named `keyman`, which no route pointed at.
  # The route is `get "projects/mightylocksmith"`, and Rails was falling back to
  # implicit rendering of app/views/projects/mightylocksmith.html.erb with no
  # matching action. That still works, but naming them the same is clearer.
  def mightylocksmith
  end

  def portfolio
  end

  def fafsa
  end

  def show
  end
end
