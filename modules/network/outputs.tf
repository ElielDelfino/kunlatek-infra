output "vpc_id" { value = aws_vpc.this.id }
output "public_subnet_ids" { value = aws_subnet.public[*].id }
output "private_subnet_ids" { value = aws_subnet.private[*].id }
output "public_subnet_azs" { value = aws_subnet.public[*].availability_zone }
output "private_subnet_azs" { value = aws_subnet.private[*].availability_zone }