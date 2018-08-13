require "rubycritic/reporters/base"
require "rubycritic/report_generators/overview"
require "rubycritic/report_generators/smells_index"
require "rubycritic/report_generators/code_index"
require "rubycritic/report_generators/code_file"
require 'json'

module Rubycritic
  module Reporter

    class Main < Base
      def initialize(analysed_files)
        @analysed_files = analysed_files
        @smells = analysed_files.flat_map(&:smells).uniq
      end

      def generate_report
        create_directories_and_files(generators)
        copy_assets_to_report_directory
        json_stat_file_location
        report_location
      end

      private

      def generators
        [overview_generator, code_index_generator, smells_index_generator] + file_generators
      end

      def overview_generator
        @overview_generator ||= Generator::Overview.new(@analysed_files)
      end

      def code_index_generator
        Generator::CodeIndex.new(@analysed_files)
      end

      def smells_index_generator
        Generator::SmellsIndex.new(@smells)
      end

      def file_generators
        @analysed_files.map do |analysed_file|
          Generator::CodeFile.new(analysed_file)
        end
      end

      def report_location
        overview_generator.file_href
      end

      def json_stat_file_location
        stat = {
          churn: 0,
          complexity: 0,
          duplication: 0,
          smell: 0
        }
        @analysed_files.each do |file|
          stat[:churn] += file.churn
          stat[:complexity] += file.complexity
          stat[:duplication] += file.duplication
          stat[:smell] += file.smells.inject(0) {|sum, i| sum += i.cost} unless file.smells.empty?
        end
        date_generation = overview_generator.file_directory.to_s.split("/").last
        path = Pathname.new(overview_generator.file_directory.to_s.split("/")[0...-1].join("/"))
        if File.exists?(path + "chart_stats.json")
          puts "File exists | Updating"
          charts_file = File.read("#{path.to_s + '/chart_stats.json'}")
          charts_data = JSON.parse(charts_file)
          charts_data["labels"] << date_generation
          charts_data["datasets"][0]["data"] << stat[:churn]
          charts_data["datasets"][1]["data"] << stat[:complexity]
          charts_data["datasets"][2]["data"] << stat[:duplication]
          charts_data["datasets"][3]["data"] << stat[:smell]
          File.open("#{path.to_s + '/chart_stats.json'}", "w+") {|f| f.write(charts_data.to_json)}
        else
          puts "File doesn't exists | Creating"
          charts_data = {
            "labels": [],
            "datasets": [{
              "label": "Churn",
              "backgroundColor": "#f56385",
              "data": []
            }, {
              "label": "Complexity",
              "backgroundColor": "#3ba2eb",
              "data": []
            }, {
              "label": "Duplication",
              "backgroundColor": "#4bc0c0",
              "data": []
            }, {
              "label": "Smells",
              "backgroundColor": "#F0E68C",
              "data": []
            }]

          }
          charts_data[:labels] << date_generation
          charts_data[:datasets][0][:data] << stat[:churn]
          charts_data[:datasets][1][:data] << stat[:complexity]
          charts_data[:datasets][2][:data] << stat[:duplication]
          charts_data[:datasets][3][:data] << stat[:smell]
          File.open("#{path.to_s + '/chart_stats.json'}", "w+") {|f| f.write(charts_data.to_json)}
        end
      end
    end

  end
end
