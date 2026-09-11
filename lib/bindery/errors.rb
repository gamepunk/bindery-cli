module Bindery
  class Error < StandardError; end
  class ProjectNotFoundError < Error; end
  class BookNotFoundError < Error; end
end
