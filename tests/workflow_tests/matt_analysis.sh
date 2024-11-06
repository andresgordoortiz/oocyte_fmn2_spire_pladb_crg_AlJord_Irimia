matt add_val share/AS_NC--dPSI25-range5-min_ALT_use25-upreg_ALT_Control-vs-Srrm4_KD-with_dPSI-Max_dPSI5.tab GROUP AS_NC | grep -P "(MmuEX|EVENT)" | matt rand_rows - 1000 > AS_NC_tmp.tab
matt add_val share/CR--dPSI25-range5-min_ALT_use25-upreg_ALT_Control-vs-Srrm4_KD-with_dPSI.tab GROUP CR | grep -P "(MmuEX|EVENT)" | matt rand_rows - 1000 > CR_tmp.tab
matt add_val share/CS--dPSI25-range5-min_ALT_use25-upreg_ALT_Control-vs-Srrm4_KD-with_dPSI.tab GROUP CS | grep -P "(MmuEX|EVENT)" | matt rand_rows - 1000 > CS_tmp.tab
matt get_rows share/DiffAS--dPSI25-range5-min_ALT_use25-upreg_ALT_Control-vs-Srrm4_KD-with_dPSI.tab dPSI[-100,-15] |  matt add_val - GROUP Srrm4_DOWN | grep -P "(MmuEX|EVENT)" > low_tmp.tab
matt add_rows AS_NC_tmp.tab CR_tmp.tab
matt add_rows AS_NC_tmp.tab CS_tmp.tab
matt add_rows AS_NC_tmp.tab low_tmp.tab
cp AS_NC_tmp.tab share/merged_tmp.tab
rm *_tmp.tab
