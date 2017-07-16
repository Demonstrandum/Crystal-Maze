require "stumpy_png"
include StumpyPNG

module CrystalMaze
  GREY = 255 / 2
  class FromTo
    def self.findEnd(image : StumpyCore::Canvas)
      0.upto image.width - 1 do |i|
        red, green, blue = image[i, image.height - 1].to_rgb8

        if red > GREY && green > GREY && blue > GREY
          return [i, image.height - 1] of Int32
        end
      end
      return [] of Int32
    end

    def self.findStart(image : StumpyCore::Canvas)
      0.upto image.width - 1 do |i|
        red, green, blue = image[i, 0].to_rgb8

        if red > GREY && green > GREY && blue > GREY
          return [i, 0] of Int32
        end
      end
      return [] of Int32
    end
  end

  class AStar
    def initialize(maze : StumpyCore::Canvas, start : Array(Int32), dest : Array(Int32), hide_nodes=true, distanceType="manhattan")
      @maze  = maze
      @start = start
      @dest  = dest
      @solvedMaze = @maze
      @firstNode  = [start[0], start[1], -1, -1, -1, -1] #[x, y, index, cost, heuristic, cost + heuristic]
      @destNode   = [dest[0],  dest[1],  -1, -1, -1, -1]

      @open    = [] of Array(Int32)
      @closed  = [] of Array(Int32)
      @open << @firstNode

      @hide_nodes = hide_nodes
      @distanceType  = distanceType
    end

    def draw
      puts "Solving..."

      go = Time.new # Start the time
      path = solve # Here we go!
      finish = Time.new # Take the finish time

      unless path.empty?
          puts "Time taken to solve: " + (finish - go).to_s + " seconds."
        minutes = ((finish - go) / 60.0).to_f.round.to_i
        if minutes > 0
          if minutes > 1
            puts "Circa " + minutes.to_s + " Minutes."
          else
            puts "Circa " + minutes.to_s + " Minute."
          end
        end
      else
        puts "No solution found, solve function returned empty array for path!\nPlease make sure your maze is solvable!"
      end


      filepath : String = ""
      ARGV.each do |argument|
        if argument.includes? ".png"
          filepath = argument
          break
        end
      end
      mazeName : String = filepath.strip
      mazeLabel : String = mazeName.split(/()\s|\./)[0]
      mazeFileType : String = "." + mazeName.split(/\s|\./)[1]
      StumpyPNG.write(@solvedMaze, mazeLabel + "-solved" + mazeFileType)
    end

    private def solve
      until @open.empty?
        min_i = 0
        0.upto @open.size - 1 do |i|
          if @open[i][5] < @open[min_i][5]
            min_i = i
          end
        end
        chosen_node = min_i

        here : Array(Int32) = @open[chosen_node]

        if here[0] == @destNode[0] && here[1] == @destNode[1]
          path = [@destNode]
          puts "\nWe\'re here! Final node at: (x: #{here[0].to_s}, y: #{here[1].to_s})"
          until here[2] == -1
            here = @closed[here[2]]
            path.unshift(here)
          end

          if (ARGV.includes?("-v")) || (ARGV.includes?("verbose")) || (ARGV.includes?("--verbose"))
            puts "The entire path from node #{@start} to node #{@dest} are the nodes: \n#{path}\n\n"
          end

          hue = 0
          hue_ratio = 360.0 / path.size # when * by path.size (the end of the arr) it would be 360, so one complete rainbow

          (1..path.size).each do |n|
            @solvedMaze[ path[n - 1][0], path[n - 1][1] ] = RGBA.from_hsl(hue, 100, 60)
            hue = (hue_ratio * n).floor # Rainbow!
          end

          return path
        end

        @open.delete_at chosen_node
        @closed << here

        friendNodes = lookAround here
        0.upto friendNodes.size - 1 do |j|
          horizontalFriend : Int32 = friendNodes[j][0]
          verticalFriend   : Int32 = friendNodes[j][1]

          if passable?(horizontalFriend, verticalFriend) || (horizontalFriend == @destNode[0] && verticalFriend == @destNode[1])
            onclosed = false
            0.upto @closed.size - 1 do |k|
              closedNode = @closed[k]
              if horizontalFriend == closedNode[0] && verticalFriend == closedNode[1]
                onclosed = true
                break
              end
            end
            next if onclosed

            on_open = false
            0.upto @open.size - 1 do |k|
              openNode = @open[k]
              if horizontalFriend == openNode[0] && verticalFriend == openNode[1]
                on_open = true
                break
              end
            end

            unless on_open
              new_node = node horizontalFriend, verticalFriend, @closed.size - 1, -1, -1, -1
              new_node[3] = here[3] + cost(here, new_node)
              new_node[4] = heuristic(new_node, @destNode).to_i
              new_node[5] = new_node[3] + new_node[4]

              @open << new_node
              #puts "!! New Node at\n(x: " + horizontalFriend.to_s + ", y: " + verticalFriend.to_s + ")"
              #puts "Destination = " + @destNode[0].to_s + ", " + @destNode[1].to_s

              unless @hide_nodes
                @solvedMaze[horizontalFriend, verticalFriend] = RGBA.from_hex "#e2e2e2"
              end
            end
          end
        end
      end
      return [] of Int32
    end

    private def node(x : Int32, y : Int32, index : Int32, cost : Int32, heuristic : Int32, totalCost : Int32)
      return [x, y, index, cost, heuristic, totalCost] of Int32
    end

    private def heuristic(here, destination)
      case @distanceType
      when "euclidean"
        return (
          Math.sqrt(
            ((destination[0] - here[0]) ** 2) +
            ((destination[1] - here[1]) ** 2)
          )
        ).floor
      end
      return (
        (destination[0] - here[0]).abs +
        (destination[1] - here[1]).abs
      )
    end

    private def cost(here, destination)
      direction = direction here, destination
      if [2, 4, 6, 8].includes? direction
        return 10
      end
      return 14
    end

    private def passable?(x : Int32, y : Int32)
      if x < 0 || y < 0 || (x > @maze.width - 1 || y > @maze.height - 1)
        return false
      end
      red, green, blue = @maze[x, y].to_rgb8
      if red > GREY && green > GREY && blue > GREY
        return true
      end
      return false
    end

    private def direction(here, destination)
      direction = [ destination[1] - here[1], destination[0] - here[0] ]
      return case
        when direction[0] > 0 && direction[1] == 0
          2 # y-negative, down
        when direction[1] < 0 && direction[0] == 0
          4 # x-negative, left
        when direction[0] < 0 && direction[1] == 0
          8 # y-positive, up
        when direction[1] > 0 && direction[0] == 0
          6 # x-positive, right
      end
    end

    private def lookAround(here)
      return [
        [here[0], (here[1] + 1)], # y-positive, up
        [here[0], (here[1] - 1)], # y-negative, down
        [(here[0] + 1), here[1]], # x-positive, right
        [(here[0] - 1), here[1]]  # x-negative, left
      ]
    end
  end
end
