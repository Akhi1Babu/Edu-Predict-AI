def generate_recommendations(data: dict, predicted_score: float, subject: str = "General") -> list[str]:
    """
    Generates personalized, actionable recommendations for students 
    based on predicted exam score, key performance drivers, and specific subject context.
    """
    recommendations = []

    # 1. Subject-Specific Specific Recommendations
    subj_upper = subject.upper()
    if "DATA" in subj_upper or "ALGORITHM" in subj_upper or "DSA" in subj_upper:
        if predicted_score < 70:
            recommendations.append(
                "DSA FOCUS: Practice solving 2-3 algorithmic problems daily on platforms like LeetCode or HackerRank to strengthen core data structure concepts."
            )
        else:
            recommendations.append(
                "DSA TIP: Review time/space complexity analysis and practice dynamic programming and graph algorithms."
            )
    elif "ARTIFICIAL" in subj_upper or "INTELLIGENCE" in subj_upper or "AI" in subj_upper:
        if predicted_score < 70:
            recommendations.append(
                "AI FOCUS: Review foundational linear algebra, probability, and standard machine learning algorithm pipelines."
            )
        else:
            recommendations.append(
                "AI TIP: Build hands-on mini projects with PyTorch/TensorFlow to solidify neural network architecture concepts."
            )
    elif "CLOUD" in subj_upper:
        if predicted_score < 70:
            recommendations.append(
                "CLOUD FOCUS: Complete hands-on labs on AWS/GCP/Azure free tiers to understand virtual networking, IAM, and container deployment."
            )
        else:
            recommendations.append(
                "CLOUD TIP: Deepen your understanding of serverless architecture, Kubernetes orchestration, and cloud security compliance."
            )

    # 2. Attendance Check (Key Driver ~15.9%)
    attendance = data.get("Attendance", 0)
    if attendance < 75:
        recommendations.append(
            f"CRITICAL: Attendance is currently at {attendance}%. Increasing class attendance to above 85% is the single fastest way to boost your score in {subject}."
        )
    elif attendance < 85:
        recommendations.append(
            f"IMPROVEMENT: Attendance is at {attendance}%. Try aiming for 90%+ attendance to maximize learning in {subject}."
        )

    # 3. Hours Studied Check (Key Driver ~11.3%)
    hours_studied = data.get("Hours_Studied", 0)
    if hours_studied < 10:
        recommendations.append(
            f"CRITICAL: Studying only {hours_studied} hours/week is holding back your {subject} score. Aim for at least 15-20 hours of focused study per week."
        )
    elif hours_studied < 18:
        recommendations.append(
            f"SUGGESTION: You currently study {hours_studied} hours/week for {subject}. Increasing study time by 3-5 hours could yield a 5+ point boost."
        )

    # 4. Tutoring Sessions
    tutoring_sessions = data.get("Tutoring_Sessions", 0)
    if predicted_score < 70 and tutoring_sessions < 2:
        recommendations.append(
            f"RECOMMENDED: Consider attending 1-2 tutoring sessions per week for difficult {subject} topics."
        )

    # 5. Access to Resources
    access_resources = data.get("Access_to_Resources", 2)
    if access_resources < 2:
        recommendations.append(
            f"RESOURCE: Utilize digital libraries and open online courses to supplement your {subject} learning materials."
        )

    # 6. Class Participation
    participation = data.get("Class_Participation_Score", 10)
    if participation < 6:
        recommendations.append(
            f"ENGAGEMENT: Active participation in {subject} lectures helps reinforce key concepts and improves exam recall."
        )

    # Default praise if performing very well
    if not recommendations or predicted_score >= 85:
        recommendations.insert(
            0, f"EXCELLENT PERFORMANCE ({subject}): You are on track for a high score! Maintain your strong study habits."
        )

    return recommendations

