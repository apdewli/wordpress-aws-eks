resource "aws_ec2_transit_gateway" "main" {
  description = "${var.project_name} Transit Gateway"
  
  tags = {
    Name = "${var.project_name}-tgw"
  }
}

resource "aws_ec2_transit_gateway_vpc_attachment" "main" {
  subnet_ids         = [data.aws_subnets.private.ids[0]]
  transit_gateway_id = aws_ec2_transit_gateway.main.id
  vpc_id             = var.vpc_id
  
  tags = {
    Name = "${var.project_name}-tgw-attachment"
  }
}

data "aws_subnets" "private" {
  filter {
    name   = "vpc-id"
    values = [var.vpc_id]
  }
  
  filter {
    name   = "tag:Type"
    values = ["private"]
  }
}