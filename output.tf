output "ssh_private_key_pem" {
  value = tls_private_key.ssh.private_key_pem
  sensitive = true
}

output "ssh_public_key_pem" {
  value = tls_private_key.ssh.public_key_pem
}

output "instance_private_ip" {
  value = aws_instance.ec2instance.private_ip
}

output "nat_gateway_ip" {
  value = aws_eip.nat_gateway.public_ip
}

output "jumphost_ip" {
  value = aws_eip.jumphost.public_ip
}