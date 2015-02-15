God.watch do |w|
  w.name = "gather_metrics"
  w.start = "ruby {{nefmon_god_dir}}/script/gather_metrics.rb"
  w.keepalive(:memory_max => {{nefmon_god_mem_max}},
              :cpu_max => {{nefmon_god_cpu_max}})
end
