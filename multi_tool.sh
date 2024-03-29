#!/bin/bash
# Default variables
function="install"
node="4133"
rpc="3033"

# Options
. <(wget -qO- https://raw.githubusercontent.com/SecorD0/utils/main/colors.sh) --
option_value(){ echo "$1" | sed -e 's%^--[^=]*=%%g; s%^-[^=]*=%%g'; }
while test $# -gt 0; do
	case "$1" in
	-h|--help)
		. <(wget -qO- https://raw.githubusercontent.com/SecorD0/utils/main/logo.sh)
		echo
		echo -e "${C_LGn}Functionality${RES}: the script installs an Aleo client or miner node"
		echo
		echo -e "${C_LGn}Usage${RES}: script ${C_LGn}[OPTIONS]${RES}"
		echo
		echo -e "${C_LGn}Options${RES}:"
		echo -e "  -h,   --help       show the help page"
		echo -e "  -n,   --node PORT  assign the specified port to use RPC (default is ${C_LGn}${node}${RES})"
		echo -e "  -r,   --rpc PORT   assign the specified port to use RPC (default is ${C_LGn}${rpc}${RES})"
		echo -e "  -up,  --update     update the node"
		echo -e "  -un, --uninstall   uninstall the node"
		echo
		echo -e "${C_LGn}Useful URLs${RES}:"
		echo -e "https://github.com/SecorD0/Aleo/blob/main/multi_tool.sh — script URL"
		echo -e "https://learning.1package.io/Aleo_RU — Russian-language guide"
		echo -e "https://t.me/OnePackage — noderun and tech community"
		echo
		return 0 2>/dev/null; exit 0
		;;
	-n*|--node*)
		if ! grep -q "=" <<< $1; then shift; fi
		node=`option_value $1`
		shift
		;;
	-r*|--rpc*)
		if ! grep -q "=" <<< $1; then shift; fi
		rpc=`option_value $1`
		shift
		;;
	-up|--update)
		function="update"
		shift
		;;
	-un|--uninstall)
		function="uninstall"
		shift
		;;
	*|--)
		break
		;;
	esac
done

# Functions
printf_n(){ printf "$1\n" "${@:2}"; }
install() {
	sudo apt update
	sudo apt upgrade -y
	sudo apt install wget jq git build-essential pkg-config libssl-dev -y
	. <(wget -qO- https://raw.githubusercontent.com/SecorD0/utils/main/installers/rust.sh)
	git clone https://github.com/AleoHQ/snarkOS.git --depth 1
	cd snarkOS
	cargo build --release
	mv $HOME/snarkOS/target/release/snarkos /usr/bin
	cd
	if [ ! -f $HOME/aleo_account.txt ]; then
		snarkos account new > $HOME/aleo_account.txt
	fi
	. <(wget -qO- https://raw.githubusercontent.com/SecorD0/utils/main/miscellaneous/insert_variable.sh) -n aleo_wallet_address -v `grep -oPm1 "(?<=Address  )([^%]+)(?=$)" $HOME/aleo_account.txt`
	. <(wget -qO- https://raw.githubusercontent.com/SecorD0/utils/main/miscellaneous/insert_variable.sh) -n aleo_private_key -v `grep -oPm1 "(?<=Private Key  )([^%]+)(?=$)" $HOME/aleo_account.txt`
	if [ ! -n "$aleo_private_key" ]; then
		printf_n "${C_R}There is no \$aleo_private_key variable!\nCheck if the contents of the file are correct:${RES} cat $HOME/aleo_account.txt"
		return 1 2>/dev/null; exit 1
	fi
	. <(wget -qO- https://raw.githubusercontent.com/SecorD0/utils/main/miscellaneous/ports_opening.sh) "$node" "$rpc"
	sudo tee <<EOF >/dev/null /etc/systemd/system/aleod.service
[Unit]
Description=Aleo Miner
After=network-online.target

[Service]
User=$USER
ExecStart=`which snarkos` start --nodisplay --prover $aleo_private_key
Restart=on-failure
RestartSec=3
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF
	sudo systemctl daemon-reload
	sudo systemctl enable aleod
	sudo systemctl restart aleod
	. <(wget -qO- https://raw.githubusercontent.com/SecorD0/utils/main/miscellaneous/insert_variable.sh) -n aleo_log -v "sudo journalctl -fn 100 -u aleod" -a
	printf_n "${C_LGn}Done!${RES}"
	. <(wget -qO- https://raw.githubusercontent.com/SecorD0/utils/main/logo.sh)
	printf_n "
The prover was ${C_LGn}started${RES}.
Remember to save this file: ${C_LR}$HOME/aleo_account.txt${RES}

\tv ${C_LGn}Useful commands${RES} v

To view the node log: ${C_LGn}aleo_log${RES}
To view the node status: ${C_LGn}sudo systemctl status aleod${RES}
To restart the node: ${C_LGn}sudo systemctl restart aleod${RES}
"
}
update() {
	if [ -f /etc/systemd/system/aleod.service ]; then
		local service_file="aleod.service"
	elif [ -f /etc/systemd/system/aleod-prover.service ]; then
		local service_file="aleod-prover.service"
	else
		printf_n "${C_R}Change the name of the service file to ${C_LGn}aleod.service${RES}"
		return 1 2>/dev/null; exit 1	
	fi
	if [ ! -d $HOME/snarkOS ]; then
		printf_n "${C_LGn}Building binary...${RES}"
		sudo systemctl stop "$service_file"
		. <(wget -qO- https://raw.githubusercontent.com/SecorD0/utils/main/installers/rust.sh)
		/usr/bin/git clone https://github.com/AleoHQ/snarkOS.git --depth 1
		cd $HOME/snarkOS
		cargo build --release
		mv $HOME/snarkOS/target/release/snarkos /usr/bin
		sudo systemctl restart "$service_file"
	else
		printf_n "${C_LGn}Checking for updates...${RES}"
		cd $HOME/snarkOS
		/usr/bin/git stash &>/dev/null
		status=`/usr/bin/git pull`
		if [ "$status" != "Already up to date." ]; then
			printf_n "${C_LGn}Updating the node...!${RES}"
			sudo systemctl stop "$service_file"
			. <(wget -qO- https://raw.githubusercontent.com/SecorD0/utils/main/installers/rust.sh)
			/root/.cargo/bin/cargo clean
			/root/.cargo/bin/cargo build --release
			mv $HOME/snarkOS/target/release/snarkos /usr/bin
			sudo systemctl restart "$service_file"
		else
			printf_n "${C_LGn}Binary file of the current version${RES}"
		fi
	fi
	cd
	printf_n "${C_LGn}Done!${RES}"
}
uninstall() {
	sudo systemctl stop aleod aleou
	sudo systemctl disable aleod aleou
	rm -rf $HOME/snarkOS/ `which snarkos` $HOME/.aleo/ /etc/systemd/system/aleod.service /etc/systemd/system/aleou.service
	sudo systemctl daemon-reload
	. <(wget -qO- https://raw.githubusercontent.com/SecorD0/utils/main/miscellaneous/insert_variable.sh) -n aleo_wallet_address -da
	. <(wget -qO- https://raw.githubusercontent.com/SecorD0/utils/main/miscellaneous/insert_variable.sh) -n aleo_log -da
	. <(wget -qO- https://raw.githubusercontent.com/SecorD0/utils/main/miscellaneous/insert_variable.sh) -n aleo_node_info -da
}

# Actions
sudo apt install wget -y &>/dev/null
. <(wget -qO- https://raw.githubusercontent.com/SecorD0/utils/main/logo.sh)
cd
$function
