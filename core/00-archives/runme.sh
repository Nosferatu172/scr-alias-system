cd /mnt/c/scr/aliases
python3 toggle.py -wsl
cd /mnt/c/scr/core
python3 toggle.py -wsl
bash acc-build.sh
bash scr-register.sh
python3 rcu.py

echo "Completo. RESTART YOUR SHELL FOR FULL EFFECT"
echo "WHEN YOU GET BACK IN RUN scr -h or scr0 -h, for the basic idea"
