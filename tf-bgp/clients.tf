resource "aws_security_group" "client" {
  name        = "client-servers"
  description = "Access to client servers"
  vpc_id      = "${aws_vpc.main.id}"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 4789
    to_port     = 4789
    protocol    = "udp"
    self        = "true"
  }

  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
  }

  tags {
    Name = "Client"
  }
}

resource "aws_instance" "docker" {
  count = "${var.docker_hosts}"
  ami                    = "${data.aws_ami.server.id}"
  instance_type          = "${var.server_type}"
  key_name               = "${var.key_pair}"
  subnet_id              = "${aws_subnet.demo.*.id[count.index]}"
  private_ip             = "${cidrhost(aws_subnet.demo.*.cidr_block[count.index],var.docker_hostnum)}"
  vpc_security_group_ids = [ "${aws_security_group.client.id}" ]
  user_data              = "${data.template_file.setup_docker.*.rendered[count.index]}"

  tags {
    Name = "Demo Docker${count.index}"
  }
}

data "template_file" "setup_docker" {
    count = "${var.docker_hosts}"
    template     = "${file("${path.module}/files/setup_host.tpl.sh")}"
    vars {
        TF_HOSTNAME = "docker${count.index}"
        TF_HOST_IP = "${cidrhost(aws_subnet.demo.*.cidr_block[count.index],var.docker_hostnum)}"
        TF_USER = "${var.docker_user}"
        TF_QUAGGA_CONF = "${data.template_file.conf_quagga_vtep_docker.*.rendered[count.index]}"
        TF_QUAGGA_NET = "bridge"
        TF_PULL_IMAGES = "cumulusnetworks/quagga:latest networkboot/dhcpd debian"
    }
}

data "template_file" "conf_quagga_vtep_docker" {
    count = "${var.docker_hosts}"
    template     = "${file("${path.module}/files/quagga-vtep.tpl")}"
    vars {
        TF_VPC_CIDR = "${var.cidr_block}"
        TF_HOST_IP = "${cidrhost(aws_subnet.demo.*.cidr_block[count.index],var.docker_hostnum)}"
        TF_ROUTE_REFLECTORS = "${join(",",aws_instance.quagga.*.private_ip)}"
        TF_QUAGGA_NET = "bridge"
    }
}

resource "aws_instance" "simple" {
  count = "${var.simple_hosts}"
  ami                    = "${data.aws_ami.server.id}"
  instance_type          = "${var.server_type}"
  key_name               = "${var.key_pair}"
  subnet_id              = "${aws_subnet.demo.*.id[count.index]}"
  private_ip             = "${cidrhost(aws_subnet.demo.*.cidr_block[count.index],var.simple_hostnum)}"
  vpc_security_group_ids = [ "${aws_security_group.client.id}" ]
  user_data              = "${data.template_file.setup_simple.*.rendered[count.index]}"

  tags {
    Name = "Demo Simple${count.index}"
  }
}

data "template_file" "setup_simple" {
    count = "${var.simple_hosts}"
    template     = "${file("${path.module}/files/setup_host.tpl.sh")}"
    vars {
        TF_HOSTNAME = "simple${count.index}"
        TF_HOST_IP = "${cidrhost(aws_subnet.demo.*.cidr_block[count.index],var.simple_hostnum)}"
        TF_USER = "${var.docker_user}"
        TF_QUAGGA_CONF = "${data.template_file.conf_quagga_vtep_simple.*.rendered[count.index]}"
        TF_QUAGGA_NET = "host"
        TF_PULL_IMAGES = "cumulusnetworks/quagga:latest"
    }
}

data "template_file" "conf_quagga_vtep_simple" {
    count = "${var.simple_hosts}"
    template     = "${file("${path.module}/files/quagga-vtep.tpl")}"
    vars {
        TF_VPC_CIDR = "${var.cidr_block}"
        TF_HOST_IP = "${cidrhost(aws_subnet.demo.*.cidr_block[count.index],var.simple_hostnum)}"
        TF_ROUTE_REFLECTORS = "${join(",",aws_instance.quagga.*.private_ip)}"
        TF_QUAGGA_NET = "host"
    }
}
