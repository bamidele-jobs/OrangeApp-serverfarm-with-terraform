#9 Launch an EC2 instance.
resource "aws_instance" "bello-server" {
  ami           = "ami-0729131ef01366759" # eu-west-2
  instance_type = "t2.micro"

  primary_network_interface {
    network_interface_id = aws_network_interface.bello-eni.id
  }
 
  root_block_device {
    volume_size           = 12      # Size in GiB
    volume_type           = "gp3"    # General Purpose SSD (gp3 is recommended)
    throughput            = 125      # Only applicable for gp3 (MiB/s)
    iops                  = 3000     # Baseline for gp3
    encrypted             = true     # Enables EBS encryption
    delete_on_termination = true     # Deletes volume when instance is destroyed
  }

key_name = "london_kp"

tags = {
    Name = "bello-server"
  }
}