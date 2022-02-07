terraform {
 backend "remote" {
    hostname = "app.terraform.io"
    organization = "my-company-aws"

    workspaces {
      name = "terraform"
    }
  }
}


provider "aws" {
    region = "us-east-1"
}

#1 create vpc
resource "aws_vpc" "test-vpc" {
  cidr_block = "192.168.0.0/16"
  tags = {
      Name = "testing-terraform"
  }
}

#2 Create Internet GW
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.test-vpc.id  #referencing

  tags = {
    Name = "main"
  }
}

#3 create Custom Route Table
resource "aws_route_table" "internet-route-table" {
  vpc_id = aws_vpc.test-vpc.id
  route = [
    {
      cidr_block = "0.0.0.0/0"
      ipv6_cidr_block = ""
      gateway_id = aws_internet_gateway.gw.id
      carrier_gateway_id = ""
      destination_prefix_list_id = ""
      egress_only_gateway_id = ""
      instance_id = ""
      local_gateway_id = ""
      nat_gateway_id = ""
      network_interface_id = ""
      transit_gateway_id = ""
      vpc_endpoint_id = ""
      vpc_peering_connection_id = ""
    },
   {
      cidr_block = ""
      ipv6_cidr_block = "::/0"
      gateway_id = aws_internet_gateway.gw.id
      carrier_gateway_id = ""
      destination_prefix_list_id = ""
      egress_only_gateway_id = ""
      instance_id = ""
      local_gateway_id = ""
      nat_gateway_id = ""
      network_interface_id = ""
      transit_gateway_id = ""
      vpc_endpoint_id = ""
      vpc_peering_connection_id = ""
    } 
  ]
  depends_on = [aws_internet_gateway.gw]

  tags = {
    Name = "Internet Route Table"
  }
}

#4 Create a subnet
resource "aws_subnet" "subnet-web" {
  vpc_id     = aws_vpc.test-vpc.id
  cidr_block = "192.168.1.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "Web Subnet"
  }
}

#5 Associate Subnet with Route Table
resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.subnet-web.id
  route_table_id = aws_route_table.internet-route-table.id
}

#6 Create Security group to allow port 22,80,443
resource "aws_security_group" "allow_web" {
  name        = "allow_web_traffic"
  description = "Allow TLS inbound traffic"
  vpc_id      = aws_vpc.test-vpc.id

  ingress = [
    {
      description      = "HTTPS from VPC"
      from_port        = 443
      to_port          = 443
      protocol         = "tcp"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = ["::/0"]
      prefix_list_ids  = []
      security_groups  = []
      self = false
    },
     {
      description      = "HTTP from VPC"
      from_port        = 80
      to_port          = 80
      protocol         = "tcp"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = ["::/0"]
      prefix_list_ids  = []
      security_groups  = []
      self = false    
    },
     {
      description      = "SSH from VPC"
      from_port        = 22
      to_port          = 22
      protocol         = "tcp"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = ["::/0"]
      prefix_list_ids  = []
      security_groups  = []
      self = false    
    }
  ]

  egress = [
    {
      description = "egress rule"
      from_port        = 0
      to_port          = 0
      protocol         = "-1"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = ["::/0"]
      prefix_list_ids  = []
      security_groups  = []
      self = false
    }
  ]

  tags = {
    Name = "allow_web_traffic"
  }
}
#7 Create a network interface with an ip in the subnet that we created above
resource "aws_network_interface" "web-server-nic" {
  subnet_id       = aws_subnet.subnet-web.id
  private_ips     = ["192.168.1.50"]
  security_groups = [aws_security_group.allow_web.id]
}

#8 Assign an elastic IP to the the network interface created in step 7
resource "aws_eip" "one" {
  vpc                       = true
  network_interface         = aws_network_interface.web-server-nic.id
  associate_with_private_ip = "192.168.1.50"
  depends_on = [aws_internet_gateway.gw]
}

output "Server_public_IP" {
  value = aws_eip.one.public_ip
}

#9 Create an instance and install apache
resource "aws_instance" "web-server-instance" {
  ami           = "ami-0a8b4cd432b1c3063"
  instance_type = "t2.micro"
  availability_zone = "us-east-1a"
  key_name = "test-keypair-ec2"

  network_interface {
    device_index = 0
    network_interface_id = aws_network_interface.web-server-nic.id
  }
  user_data = <<-EOF
              #!/bin/bash
              sudo yum install -y
              sudo yum install httpd -y
              sudo systemctl start httpd
              sudo bash -c 'echo your very first web server > /var/www/html/index.html'
              EOF
  tags = {
    Name = "WebServer1"
  }
}
