# Sovereign-Vault-Infrastructure
```markdown
## 🚀 Development Roadmap (Sovereign Vault)
本プロジェクトは、実運用に向けたエンタープライズ要件を満たすため、段階的なフェーズでアジャイルに構築を進行しています。

- [x] **Phase 1: コアストレージの構築 (Current)**
  - S3 Object Lock (Compliance Mode) による10年間のデータ不変性の担保
  - CloudTrailによるAPI監査ログの取得と専用バケットへの保管
  - KMSキーによる暗号化とハードウェアMFAを前提としたIAM権限保護

- [ ] **Phase 2: 実運用向けIaC最適化 (In Progress)**
  - Terraform State (.tfstate) のS3 + DynamoDBによるセキュアなリモート管理・ロック機能の実装
  - ライフサイクルルールによる、30日経過後のGlacierへの自動アーカイブ（コスト最適化）

- [ ] **Phase 3: グローバル展開 (Planned)**
  - USリージョン（us-east-1等）を含めたマルチリージョンへの拡張
  - ディザスタリカバリ（DR）要件を満たすクロスリージョンレプリケーションの自動化
## 概要
AWSとTerraformを用いた、法的証拠保全要件を満たす完全不変（Immutable）なセキュア・ストレージのIaC構築リポジトリです。

## アーキテクチャの要点と設計意図
- **絶対不変性の担保**: S3 Object Lock (COMPLIANCEモード) による10年間の削除・変更ロック。AWSのルート権限でも意図的なデータ破壊・変更が不可能な構成。
- **暗号シュレッディング対策**: AWS KMSキーのローテーション有効化および、IAMポリシーによる意図的なキー削除（Disable/ScheduleKeyDeletion）の完全ブロック。
- **証拠能力の担保**: AWS CloudTrailによるS3バケット内のデータイベントの完全追跡と、ログバケットへのセキュアな保管。

## 技術スタック
- Terraform (>= 1.5.0)
- AWS (S3, KMS, CloudTrail, IAM)
