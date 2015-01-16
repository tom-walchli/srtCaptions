#####################################################################
#  																	#
#   A routine that outputs unformatted text into SRT subtitles		#
#   of a predefined length of lines. Each line is equipped with 	#
#   an index number as well as start- and end-time.					#
#  																	#
# 	Potential typos are collected in possibleTypos.txt 				#
#  																	#
#   Optionally, CENSORING of offensive language can 				#
# 	be activated ($censor = true)									# 
#																    #
##################################################################### 	

# minimum time to show caption  [sec]
$minShowing = 2 		# seconds
# maximum time to show caption  [sec]
$maxShowing = 4 		# seconds
# minimum time between captions [sec]
$minBetween = 0 		# seconds
# maximum time between captions [sec]
$maxBetween = 1 		# seconds

# shift time at caption index
$shiftTime_idx 	= 10
# shift time by [ms]
$shiftTime_ms 	= 20000

# censor offensive language
$censor 	= true
# do spellcheck
$spellCheck = true

require 'date'


class PrepareFile
 
 	def self.prep(filename)
		newsArr = IO.read(filename).split(" ")
		newslines = []

		while newsArr.length > 0
			count = 0
			s = ""
			while s.length < 40
				s += " #{newsArr.shift}"
			end
			newslines.push(s)
		end
		puts newslines
#		IO.write("newsLines.txt" )

		t = Time.new(0) 

		IO.write("srtNews.txt", "")

		diffBetween = $maxBetween - $minBetween
		diffShowing = $maxShowing - $minShowing

		newslines.each_with_index do |s,j|
			t += minBetween + (diffBetween * rand)
			t1 = formatTime(t)
			t += minShowing + (diffShowing * rand)
			t2 = formatTime(t)
			s = "#{j} :: #{t1} --> #{t2} ::#{s}\n" 
			IO.write("srtNews.txt", s, mode: 'a')
		end

 	end

 	def self.formatTime(t)
 		puts t.strftime("%H:%M:%S,%L")
 		return t.strftime("%H:%M:%S,%L")
	end
end 

#   Don't do this unless you need to recreate your input file!!	    #
#PrepareFile.prep("newsRaw.txt")



#OUTPUT
$HASH = {}
class PrepareHash

	def initialize(filename)
		@allArr 	= IO.read(filename).split("\n")
		prepare
	end

	def prepare
		@allArr.each do |s|
			a = s.split(" :: ")
			times = a[1].split(" --> ")
			t = []
			times.each do |time|  				#time is string
				milliSplit = time.split(",")
				dts = milliSplit[0].split(":")
				ti = Time.new(0) + (dts[0].to_i*3600 + dts[1].to_i*60 + dts[2].to_i + milliSplit[1].to_f/1000)
				t.push(ti)
			end
			$HASH[a[0].to_i] = {:start => t[0], :end => t[1], :diff => (t[1] - t[0]), :text => a[2]}
		end
	end
end

class ShiftTime
	def initialize()
		@index 		= $shiftTime_idx.to_i
		@shift_ms 	= $shiftTime_ms.to_f
		doShift
		ValidateContinuation.doIt(:shiftTime)
	end

	def doShift
		$HASH.each do |obj|
			if obj[0] >= @index
				times = [obj[1][:start],obj[1][:end]]
				times.each_with_index do |time , j|  					#time is now Time-instance
					time += @shift_ms.to_f/1000
#			 		puts obj[0].to_s + ":  " + time.strftime("%H:%M:%S,%L")
			 		case j
			 		when 0
			 			obj[1][:start] 	= time
			 		when 1
			 			obj[1][:end] 	= time
			 		end
				end
#				p obj
			end
		end
	end
end

class SpellCheck
	def initialize 
		doValidation()
		ValidateContinuation.doIt(:spellCheck)
	end

	def doValidation
		checkWords = CheckWords.new("typo")
		$HASH.each do |obj|
			wordArr = Utilities.getArrayOfWordsInLine(obj[1][:text])
			wordArr.each do |s|
				s = checkWords.checkWord(s)
			end
		end
	end
end

class ProfanityFilter
	def initialize
		puts "Hello World, FUCK OFF!! (Oooops, should be censored...)"
		checkProfanity
		ValidateContinuation.doIt(:censor)
	end

	def checkProfanity
		checkWords = CheckWords.new("dirty")
		$HASH.each do |obj|
			wordArr = Utilities.getArrayOfWordsInLine(obj[1][:text])
			wordArr.each do |s|
				s = checkWords.checkWord(s)
			end
		end
	end
end

class CheckWords
	def initialize(typo_or_dirty) # ->> 'typo' OR 'dirty'
		@type = typo_or_dirty
		if typo_or_dirty == "dirty"
			@words = IO.read("offensiveWords.txt").split("\n")
		elsif typo_or_dirty == "typo"
			IO.write("possibleTypos.txt","")
			@words = IO.read("../../words").split("\n")
		else 
			puts "Something wrong with CheckWords...!!"
		end
	end

	def checkWord(s)
		case @type
		when "dirty"
			@words.each do |nastyWord|
				if s.include? nastyWord
					return "CENSORED"
				end
			end
		when "typo"
			if !@words.find(s)
				s = "**#{s}**"
				IO.write("possibleTypos.txt", s, mode: 'a')
				return s
			end
		end
	end
end

class ValidateContinuation

	def self.doIt(fromStep)

		case fromStep
		when :shiftTime
			if 	$spellCheck
				SpellCheck.new 
				return
			elsif $censor
				ProfanityFilter.new 
				return
			else 
				Display.new
				return
			end
		when :spellCheck
			if $censor
				ProfanityFilter.new 
				return
			else 
				Display.new
				return
			end
		when :censor
			Display.new
			return
		else
			puts "Ooops, something wrong with continuation...!!!"
		end
	end
end

class Display
	def initialize
		puts "Hi, we're in Display now...!!"
		printDisplay
	end

	def printDisplay 
		$HASH.each do |obj|
			# HERE GOES THE OUTPUT...
			# Do whatever has to be done for displaying the captions.
			# Thinking of timers using the live times of each caption
			# as defined in $HASH, delimated by clearScreen
		end
	end
end

class Utilities
	def self.getArrayOfWordsInLine(s)
		return s.split(" ")
	end
end

PrepareHash.new("srtNews.txt") 		# arg: some file containing text
ShiftTime.new() 			















