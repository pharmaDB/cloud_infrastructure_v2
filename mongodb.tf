#
# This file contains terraform infrastructure code to deploy a MongoDB database
# on an Ubuntu 20.04 EC2 instance for the pharmaDB backend
#
# @author Anthony Mancini
# @version 2.0.0
# @license GNU GPLv3 or later
#

# Setting AWS as the provider with North Virginia as the region
provider "aws" {
  region = "us-east-1"
}

# Specifying the keypair that will be used for the Neo4J instance
resource "aws_key_pair" "mongodb_ubuntu_20_db_key_pair" {
  key_name   = "mongodb_key"
  public_key = file("mongodb_key.pub")
}

# Creating a new security group for the MongoDB instance and allowing HTTP, 
# HTTPS, SSH, and MongoDB inbound traffic
resource "aws_security_group" "mongodb_ubuntu_20_db_security_group" {
  name        = "mongodb_ubuntu_20_db_security_group"
  description = "Allow inbound HTTP, HTTPS and SSH traffic"

  # Allowing SSH traffic into the machine
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allowing HTTPS traffic into the machine
  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allowing HTTP traffic into the machine
  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allowing MongoDB traffic into the machine
  ingress {
    description = "MongoDB"
    from_port   = 27017
    to_port     = 27017
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allowing all outbound traffic from the machine
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "mongodb_security_group"
  }
}

#
# EC2 Instance for the MongoDB Database
#
resource "aws_instance" "mongodb_ubuntu_20_db_instance" {
  # AMI for Ubuntu 20.04 Server instance
  ami           = "ami-042e8287309f5df03"

  # t2.small instance has 2 GB of RAM, and can be adjusted upwards as 
  # additional RAM is needed to run Neo4J
  instance_type = "t2.small"

  # Setting this variable to true in order to connect to our instance with SSH
  associate_public_ip_address = true

  # Setting the SSH keypair that will be associated with the instance
  key_name         = "mongodb_key"

  # Associating this instance with the newly created mongodb security group
  vpc_security_group_ids = [aws_security_group.mongodb_ubuntu_20_db_security_group.id]

  # A tag identifying the MongoDB instance
  tags = {
    Name = "mongodb_ubuntu_20_db_instance"
  }

  # Adding an additional 30 GB of storage to the EC2 instance in order to have 
  # enough space for the MongoDB database and the associated data
  root_block_device {
    volume_type           = "standard"
    volume_size           = 70
    delete_on_termination = true
  }

  # Setting up a file provisioner to ssh the post install script to the EC2
  # instance after it has been created
  provisioner "file" {
    source      = "./mongodb_postinstall.sh"
    destination = "~/mongodb_postinstall.sh"
  }

  # Setting up the SSH connection that will be used with the file provisioner
  # to run the post install script
  connection {
    type        = "ssh"
    user        = "ubuntu"
    password    = ""
    private_key = file("mongodb_key")
    host        = self.public_ip
  }

  # Runs the post install script that will download Docker and pull the docker
  # container for MongoDB, and then run the MongoDB container. See the post 
  # install bash script in this repository for more information.
  provisioner "remote-exec" {
    inline = [
      "chmod +x ~/mongodb_postinstall.sh",
      "sudo ~/mongodb_postinstall.sh",
    ]
  }
}
