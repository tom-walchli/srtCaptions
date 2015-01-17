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

# number of characters per line of captions (+/- one word...)
$charsPerLine = 40

# minimum time to show caption  [sec]
$minShowing = 2 		# seconds
# maximum time to show caption  [sec]
$maxShowing = 4 		# seconds
# minimum time between captions [sec]
$minBetween = 0 		# seconds
# maximum time between captions [sec]
$maxBetween = 1 		# seconds

# start shifting time at caption index
$shiftTime_idx 	= 10
# shift time by [ms]
$shiftTime_ms 	= 200000

# censor offensive language
$censor 		= true
# do spellcheck
$spellCheck 	= true

#output filename
$outFN = "output.txt"

require 'date'

class PrepareFile
 
 	def self.prep(filename_in, filename_out)
		newsArr = IO.read(filename_in).split(" ")
		newslines = []

		while newsArr.length > 0
			count = 0
			s = ""
			while s.length < $charsPerLine
				s += " #{newsArr.shift}"
			end
			newslines.push(s)
		end

		t = Time.new(0) 

		IO.write(filename_out, "")

		diffBetween = $maxBetween - $minBetween
		diffShowing = $maxShowing - $minShowing

		newslines.each_with_index do |s,j|
			t += $minBetween + (diffBetween * rand)
			t1 = formatTime(t)
			t += $minShowing + (diffShowing * rand)
			t2 = formatTime(t)
			s = "#{j} :: #{t1} --> #{t2} ::#{s}\n" 
			IO.write("srtNews.txt", s, mode: 'a')
		end

 	end

 	def self.formatTime(t)
# 		puts t.strftime("%H:%M:%S,%L")
 		return t.strftime("%H:%M:%S,%L")
	end
end 

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
			times.each do |time|  						#time is string
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
				times.each_with_index do |time , j|  	#time is now Time-instance (in PrepareHash was String)
					time += @shift_ms.to_f/1000
			 		case j
			 		when 0
			 			obj[1][:start] 	= time
			 		when 1
			 			obj[1][:end] 	= time
			 		end
				end
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
			checkedWordsArr = wordArr.map { |s|	checkWords.checkWord(s) }
			obj[1][:text] = checkedWordsArr.join(" ")
		end
	end
end

class ProfanityFilter
	def initialize
		checkProfanity
		ValidateContinuation.doIt(:censor)
	end

	def checkProfanity
		checkWords = CheckWords.new("dirty")
		$HASH.each do |obj|
			wordArr = Utilities.getArrayOfWordsInLine(obj[1][:text])
			checkedWordsArr = wordArr.map { |s|	checkWords.checkWord(s) }
			obj[1][:text] = checkedWordsArr.join(" ")
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
			wds = IO.read("../../words").split("\n")
			@words = wds.map {|word| word.chomp.downcase}
		else 
			puts "Only 'typo' or 'dirty' allowed as parameter in CheckWords!"
		end
	end

	def checkWord(s)q
		case @type
		when "dirty"
			@words.each do |nastyWord|
				if s.include?(nastyWord)
					puts "dirty word found: #{s}"
					return "CENSORED"
				end
			end
			return s
		when "typo"
			####
			# for some reason this ain't working :-( 
			####
			# if !(s in @words)
			# 	puts "Possible typo found: #{s}"
			# 	IO.write("possibleTypos.txt", s, mode: 'a')
			# 	s = "**#{s}**"
			# end
			ss = s.chomp.downcase
			# this is REALLY slow!!!
			@words.each do |word|
				if word == ss
					return s
				end
			end
			puts "Possible typo found: #{s}"
			IO.write("possibleTypos.txt", "#{s}\n", mode: 'a')
			s = "**#{s}**"
			return s
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
				Display.new($outFN)
				return
			end
		when :spellCheck
			if $censor
				ProfanityFilter.new 
				return
			else 
				Display.new($outFN)
				return
			end
		when :censor
			Display.new($outFN)
			return
		else
			puts "Ooops, something wrong with continuation...!!!"
		end
	end
end

class Display
	def initialize(outFN)
		@outFN = outFN
		puts "Hi, we're in Display now...!!"
		printDisplay
		puts "Done!!"
	end

	def printDisplay 
		# HERE GOES THE OUTPUT...
		# Do whatever has to be done for displaying the captions.
		# Thinking of a Timer using the live times of each caption
		# as defined in $HASH
		#
		# later...
		#
		# weeell, for now, let's just dump it all in a file...
		IO.write(@outFN,"")
		$HASH.keys.each do |key|
			obj = $HASH[key]
			outStr = 
"""
#{key}
#{PrepareFile.formatTime(obj[:start])} --> #{PrepareFile.formatTime(obj[:end])}
#{obj[:text]}
"""
			IO.write(@outFN, outStr, mode: 'a')
		end
	end
end

class Utilities
	def self.getArrayOfWordsInLine(s)
		return s.split(" ")
	end
end

rawText = "newsRawDirty.txt"
srtPrep = "srtNews.txt"

PrepareFile.prep(rawText,srtPrep)
#	    		 input  ,output

PrepareHash.new(srtPrep)
# 				input: output of PrepareFile.prep 


ShiftTime.new() 			















