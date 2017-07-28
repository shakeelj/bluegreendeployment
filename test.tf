# This configuration is to create EC2 instance, to perform basic configuration.
# Intended to use in build image process. Making ami

# Define build environment
provider "aws" {
  
  alias = "build"

  # Region still required
  region = "us-east-1"

  # this one has to be set up with credentials and profile
  shared_credentials_file = "/var/lib/jenkins/.aws/credentials"
  profile = "staging"

}

# Define build image access key
resource "aws_key_pair" "builder" {
  # Use our provider for the build
  provider = "aws.build"
  key_name   = "builder-key"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCnXKNmwJd9Avu1DAqCoJ+J6Oyz1y41qgElm+BJ/YrZk7Z7P3brbOsVlloPIyaJqK1yb/pEgFB0OadOv2TwXgf0fM4QMUuBTnUfJoNd+tRLkEr9bU5+XHNJ/pF3NdH26fFysWLkyWiBu5gtgalOyLNr8a+Si+c9Q6HgD9MV/NjfTmm64t8NeXtULFcypZ+GFIW6mRXJ9OrER4A81QsSMq8euMRgi4fnNvJzsdhTdz8BVbNf4Zgs6Ahuk0h1qzlrxLKMtqNo2+fEsDHboWJNkcFzCrJkMO/5XjoMsQ8mD8eZKow3Yuqy62kODmeFXeV5kMyiFHOhwvG3Hg7oRhadatWb jenkins@ip-10-168-1-133"
}

resource "aws_security_group" "aws_sec" {
  name        = "allow_build_image"
  description = "Allow build image"
  provider = "aws.build"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # use tags to identify environment, futher cleanup
  tags {
    Name = "Allow build image"
    env = "build"
    class = "imagesrc"
  }
}

# Define base image parameters.
data "aws_ami" "optapp" {

  # Use our provider for the build
  provider = "aws.build"

  # One can filter by regex
  # name_regex = "^amzn-ami.+\\d+.+gp2$"

  # In case there is multiple images, use recent on.
  most_recent = true

  # Filter ami images by name
  filter {
    name   = "name"
    values = [ 
      "amzn-ami-hvm-2017.03.1.20170623-x86_64-gp2", 
      "amzn-ami-hvm-2017.03.*-x86_64-gp2" 
    ]
  }

  # Filter by VT
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  # One can filter by owner id
  # owners = ["099720109477"]
}

# Describe resource
resource "aws_instance" "optapp" {

  # Use defined build environment
  provider = "aws.build"

  # User defined build image
  ami           = "${data.aws_ami.optapp.id}"
  instance_type = "t2.micro"
  count = 1

  # Use builder ssh key
  key_name = "builder-key"

  security_groups = [
   "${aws_security_group.aws_sec.name}"
  ]


  # Define tags as needed.
  # Name: uniq across builds
  # end: filter build environment
  # class: mark instances as "image preparation instances"
  tags {
    Name = "BLD: xxx"
    env = "build"
    class = "imagesrc"
  }

  # Save data locally for futher reference
  #provisioner "local-exec" {
  #  command = "echo ${resource} > resource.txt"
  #}

  # Copy deploy script\whatever to use on the host
  provisioner "file" {
    source      = "test.sh"
    destination = "~/test.sh"

    connection {
      type = "ssh"
      user = "ec2-user"
      # password = ""
      private_key = "${file("/var/lib/jenkins/.ssh/id_rsa.pub")}"
      # agent = true
    }
  }

  # Execute commands, use copied files.
  provisioner "remote-exec" {
    connection {
      type = "ssh"
      user = "ec2-user"
      # password = ""
      private_key = "${file("/var/lib/jenkins/.ssh/id_rsa.pub")}"
      # agent = true
    }
    inline = [
     "ls -la",
     "sudo ls -la",
     "sudo yum check-update",
     "echo ${aws_instance.optapp.private_ip}",
     "chmod u+x,g+x,o+x ~/test.sh",
     "sudo /home/ec2-user/test.sh"
    ]
  }

  # Copy and execute script as is
  provisioner "remote-exec" {
    connection {
      type = "ssh"
      user = "ec2-user"
      # password = ""
      private_key = "${file("/var/lib/jenkins/.ssh/id_rsa.pub")}"
      # agent = true
    }
    script = "test.sh"
  }
}

output "optapp_ip" {
  value = "${aws_instance.optapp.public_ip}"
}

output "optapp_id" {
  value = "${aws_instance.optapp.id}"
}
