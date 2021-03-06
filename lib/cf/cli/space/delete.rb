require "cf/cli/space/base"

module CF::Space
  class Delete < Base
    desc "Delete a space and its contents"
    group :spaces
    input :organization, :desc => "Space's organization",
      :aliases => ["--org", "-o"], :from_given => by_name(:organization),
      :default => proc { client.current_organization }
    input :spaces, :desc => "Spaces to delete", :argument => :splat,
      :singular => :space, :from_given => space_by_name
    input :recursive, :desc => "Delete recursively", :alias => "-r",
      :default => false, :forget => true
    input :warn, :desc => "Show warning if it was the last space",
      :default => true
    input :really, :type => :boolean, :forget => true, :hidden => true,
      :default => proc { force? || interact }

    def delete_space
      spaces = input[:spaces, org]

      deleted_current = false

      spaces.each do |space|
        next unless input[:really, space]

        deleted_current ||= (space == client.current_space)

        begin
          with_progress("Deleting space #{c(space.name, :name)}") do
            space.delete!
          end
        rescue CFoundry::APIError => boom
          line
          line c(boom.description, :bad)
          line c("If you want to delete the space along with all dependent objects, rerun the command with the #{b("'--recursive'")} flag.", :bad)
        end
      end

      if deleted_current
        line
        line c("The space that you were targeting has now been deleted. Please use #{b("`cf target -s SPACE_NAME`")} to target a different one.", :warning)
      end
    end

    private

    def ask_really(space)
      ask("Really delete #{c(space.name, :name)}?", :default => false)
    end

    def ask_recursive
      ask "Delete #{c("EVERYTHING", :bad)}?", :default => false
    end
  end
end
