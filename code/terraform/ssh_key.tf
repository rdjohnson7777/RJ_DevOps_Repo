resource "aws_key_pair" "github_runner_pub_key" {
  key_name   = "github-runner-public-key"
  public_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBT6i5ZEusVz8gycw9mZMUyKNdioMtr1sTDWS+u6FnXZ github-ansible"
}
