
                                                              
                              
                               
 
       
                                      
                                                 
                                    
                                                   
                                                              

                                                              
            
                                         
                                                              
create_clock -name clk -period 20 -waveform {0 10} [get_ports {clk}]

                                                              
                  
                                                              
derive_clocks

                                                              
                 
                        
                                 
                                   
                                
 
                                                   
                                                              
rename_clock -name {sd_card_clk} -source [get_ports {clk}] -master_clock {clk} [get_pins {sys_pll_m0/pll_inst.clkc[0]}]
rename_clock -name {ext_mem_clk} -source [get_ports {clk}] -master_clock {clk} [get_pins {sys_pll_m0/pll_inst.clkc[1]}]
rename_clock -name {video_clk}   -source [get_ports {clk}] -master_clock {clk} [get_pins {video_pll_m0/pll_inst.clkc[0]}]
rename_clock -name {hdmi_5x_clk} -source [get_ports {clk}] -master_clock {clk} [get_pins {video_pll_m0/pll_inst.clkc[1]}]


                                                              
                                          
 
          
                                                                 
                                                                  
                                      
 
                                                         
                                    
 
                                                       
                                                    
                                                              
set_clock_groups -exclusive \
    -group [get_clocks {video_clk}] \
    -group [get_clocks {hdmi_5x_clk}]



                                                              
                                                   
                                                            
                  
 
                 
                                
                                                              
                                  
                                         
                                         
                                       
                                       

                                                              
                                
                          
                                                              

                                                              
                    
                                                              
                            
                                        
                                                              

                    
set_false_path -from [get_ports {rst_n}]

                                                     
set_false_path -to [get_regs -hier {*/s1}]
                                                   
                                              
                                                     
                                                                
                                                               
set_false_path -from [get_regs -hier {*/s1}]
                                                  
                                   
set_false_path -from [get_regs -hier {*/asy_w_rst0*}] -to [get_regs -hier {*/asy_w_rst1*}]
set_false_path -from [get_regs -hier {*/asy_r_rst0*}] -to [get_regs -hier {*/asy_r_rst1*}]
                         
                                                              
                            
                                                                              
                                                                              
                                      
                               
                                                             
                                                                   
 
               
                                                        
                                                  
                                                     
                                                          
                                                                  
                                                   
                                                        
                                                            
 
                                                                 
                                            
                          
set_false_path -to [get_pins -hier {*asy_w_rst*.sr *asy_r_rst*.sr}]

                                                 
                                                     
                    
                                                                 
                                          
                                                
                                                                       
set_false_path -to [get_regs -hier {*state_code_s1*}]
set_false_path -to [get_regs -hier {*err_code_s1*}]

                                              
                                         
                                                            
set_false_path -from [get_clocks {ext_mem_clk}] -to [get_pins {sys_pll_m0/pll_inst.clkc[2]}]
set_false_path -from [get_pins {sys_pll_m0/pll_inst.clkc[2]}] -to [get_clocks {ext_mem_clk}]

                                                           
                                                          
                                                                        
                                                
                                                              
                                          
                                     
                                                                      

                                           
set_max_delay -from [get_clocks {hdmi_5x_clk}] \
    -to [get_ports {HDMI_CLK_P HDMI_D0_P HDMI_D1_P HDMI_D2_P}] \
    8.000 -datapath_only

                                                              
            
                                                              

                                                              
                     
                                                              
                            
                                                                                           
                                                                 
                       
 
                          
                                                       
                                                      
                                                          
 
                    
                                                                
                                            
                                                         
                                                              
set_false_path -to [get_pins -hier {*u_media_frame_reader*underflow*.sr}]
set_false_path -to [get_pins -hier {*underflow*_reg*.sr}]

                                                              
                               
                                                              
                  
                                                                            
                                                           
 
                                                   
                                            
                                                 
                                                              
set_false_path -to [get_pins -hier {*u_media_frame_reader*add0*.sr}]
set_false_path -to [get_pins -hier {*u_media_frame_reader*issued_count*.sr}]

