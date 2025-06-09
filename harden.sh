#!/usr/bin/bash

expected_venv="(ttcad25a)"
if [ $VIRTUAL_ENV_PROMPT != $expected_venv ]; then
    echo "Aborting: VIRTUAL_ENV_PROMPT is '$VIRTUAL_ENV_PROMPT'; expected '$expected_venv'"
    echo "You should make sure you do: source ./env-ttcad25a.sh"
    echo "If you want to force the harden to run anyway, you can do:"
    echo "  VIRTUAL_ENV_PROMPT='$expected_venv' $0 $*"
    exit 1
fi

echo "Regenerating user config..."
./tt/tt_tool.py --create-user-config
sed -i -re 's/^[{]/{"ROUTING_CORES":20,/' src/user_config.json
head -3 src/user_config.json
echo "$(date): Hardening..."
./tt/tt_tool.py --harden
if egrep 'design__instance__utilization|design__instance__count__stdcell' runs/wokwi/final/metrics.csv; then
    cp runs/wokwi/final/pnl/tt_um_algofoogle_raybox_zero.pnl.v test/gate_level_netlist.v
    date
    ls -al test/gate_level_netlist.v runs/wokwi/final/gds/*.gds
    ./tt/tt_tool.py --create-png
    xdg-open gds_render.png
else
    echo "FAILED?"
fi
wc -l runs/wokwi/error.log

echo "$(date): END"
