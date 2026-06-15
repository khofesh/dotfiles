# raspi4 config

## picoclaw.service

```shell
mkdir -p ~/.config/systemd/user
mv picoclaw.service ~/.config/systemd/user/
systemctl --user daemon-reload
systemctl --user enable --now picoclaw.service
systemctl --user status picoclaw.service
# run at boot (even without logging in)
sudo loginctl enable-linger fahmi
```

## related git

- https://github.com/khofesh/plantower_PMS9003M
