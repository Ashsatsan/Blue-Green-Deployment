output "cluster_id" {
  value = aws_eks_cluster.bg_cluster.id
}

output "node_group_id" {
  value = aws_eks_node_group.bg_node_group.id
}

output "vpc_id" {
  value = aws_vpc.bg_vpc.id
}

output "subnet_ids" {
  value = aws_subnet.bg_subnet[*].id
}
