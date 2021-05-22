provider "aws" {
    region = "ap-south-1"
    access_key = "AKIAXF5RCSPZHFJF4NG6"
    secret_key = "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"
}


resource "aws_vpc" "terraform-vpc" {
    cidr_block = "10.0.0.0/16"
    instance_tenancy = "default"
    enable_dns_support = "true"
    enable_dns_hostnames = "true"
    enable_classiclink = "false"
    tags= {
        Name = "terraform"
    }
}

resource "aws_subnet" "public-1" {
    vpc_id = "${aws_vpc.terraform-vpc.id}"
    cidr_block ="10.0.1.0/24"
    map_public_ip_on_launch = "false"
    availability_zone = "ap-south-1b"
    tags= {
       Name = "public"
    }
}


resource "aws_internet_gateway" "gw" {
    vpc_id = "${aws_vpc.terraform-vpc.id}"
    tags= {
       Name = "internet-gateway"
    }
}

resource "aws_route_table" "rt1" {
    vpc_id = "${aws_vpc.terraform-vpc.id}"
    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = "${aws_internet_gateway.gw.id}"
    }
    tags ={
       Name = "Default"
    }
}


resource "aws_route_table_association" "association-subnet" {
     subnet_id = "${aws_subnet.public-1.id}"
     route_table_id = "${aws_route_table.rt1.id}"
}
resource "tls_private_key" "ins_private_key" {
    algorithm = "RSA"
    rsa_bits = 4096
}
resource "local_file" "private_key" {
    content = tls_private_key.ins_private_key.private_key_pem
    filename = "ins_key.pem"
    file_permission = 0400
}
resource "aws_key_pair" "ins_key" {
    key_name = "instane key"
    public_key = tls_private_key.ins_private_key.public_key_openssh
}

resource "aws_security_group" "websg" {
    name = "security_instance"
    vpc_id = "${aws_vpc.terraform-vpc.id}"
    ingress {
        from_port = 8080
        to_port = 8080
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
    ingress {
        description = "http"
        from_port   = 80
        to_port     = 80
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
 
    }
    ingress {
        description = "ssh"
        from_port   = 22
        to_port     = 22
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
    egress {
        from_port   = 0
        to_port     = 0
        protocol    = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
}
resource "aws_instance" "terraform_linux" {
    ami = "ami-0bcf5425cdc1d8a85"
    instance_type = "t2.micro"
    associate_public_ip_address = "true"
    vpc_security_group_ids = ["${aws_security_group.websg.id}"]
    subnet_id = "${aws_subnet.public-1.id}"
    user_data = <<-EOF
    #!/bin/bash
    echo "hello, world" >index.html
    nohup busybox httpd -f -p 80 &
    EOF

    lifecycle {
       create_before_destroy = true
    }

    tags= {
       Name = "terraform-example"
    }
}

output "vpc-id" {
    value = "${aws_vpc.terraform-vpc.id}"
}

output "vpc-publicsubnet" {
    value = "${aws_subnet.public-1.cidr_block}"
}

output "vpc-publicsubnet-id" {
    value = "${aws_subnet.public-1.id}"
}

output "public_ip" {
    value = "${aws_instance.terraform_linux.public_ip}"
}