# Sovereign-Vault-Infrastructure

## 概要
AWSとTerraformを用いた、法的証拠保全要件を満たす完全不変（Immutable）なセキュア・ストレージのIaC構築リポジトリです。

## アーキテクチャの要点と設計意図
- **絶対不変性の担保**: S3 Object Lock (COMPLIANCEモード) による10年間の削除・変更ロック。AWSのルート権限でも意図的なデータ破壊・変更が不可能な構成。
- **暗号シュレッディング対策**: AWS KMSキーのローテーション有効化および、IAMポリシーによる意図的なキー削除（Disable/ScheduleKeyDeletion）の完全ブロック。
- **証拠能力の担保**: AWS CloudTrailによるS3バケット内のデータイベントの完全追跡と、ログバケットへのセキュアな保管。

## 技術スタック
- Terraform (>= 1.5.0)
- AWS (S3, KMS, CloudTrail, IAM)
