using UnityEngine;

namespace TerrainTools.Visualization
{
    public class Overlay
    {
        private GameObject GameObject { get; }
        private ParticleSystem.Particle[] particles = new ParticleSystem.Particle[2];
        private Transform Transform { get; }

        public ParticleSystem ps { get; }
        public ParticleSystemRenderer psr { get; }
        public ParticleSystem.MainModule psm { get; }

        public bool Enabled
        {
            get { return GameObject.activeSelf; }
            set { GameObject.SetActive(value); }
        }

        public Vector3 Position
        {
            get { return Transform.position; }
            set { Transform.position = value; }
        }

        public Vector3 LocalPosition
        {
            get { return Transform.localPosition; }
            set { Transform.localPosition = value; }
        }

        public Quaternion Rotation
        {
            get { return Transform.rotation; }
            set { Transform.rotation = value; }
        }

        public Color Color
        {
            get
            {
                var count = ps.GetParticles(particles, particles.Length);
                return count > 0 ? particles[Mathf.Min(1, count - 1)].GetCurrentColor(ps) : StartColor;
            }
        }

        public Color StartColor
        {
            get { return psm.startColor.color; }
            set { var psMain = psm; psMain.startColor = value; }
        }

        public Vector3 LocalScale
        {
            get { return Transform.localScale; }
            set { Transform.localScale = value; }
        }

        public float StartSize
        {
            get { return psm.startSize.constant; }
            set
            {
                if (Mathf.Approximately(psm.startSize.constant, value)) return;

                var psMain = ps.main;
                psMain.startSize = value;
                if (particles.Length < ps.particleCount)
                    particles = new ParticleSystem.Particle[ps.particleCount];
                var count = ps.GetParticles(particles, particles.Length);
                for (var i = 0; i < count; i++) particles[i].startSize = value;
                if (count > 0) ps.SetParticles(particles, count);
            }
        }

        public float StartSpeed
        {
            get { return psm.startSpeed.constant; }
            set { var psMain = ps.main; psMain.startSpeed = value; }
        }

        public float StartLifetime
        {
            get { return psm.startLifetime.constant; }
            set { var psMain = ps.main; psMain.startLifetime = value; }
        }

        public bool SizeOverLifetimeEnabled
        {
            get { return ps.sizeOverLifetime.enabled; }
            set { var psSizeOverLifetime = ps.sizeOverLifetime; psSizeOverLifetime.enabled = value; }
        }

        public ParticleSystem.MinMaxCurve SizeOverLifetime
        {
            get { return ps.sizeOverLifetime.size; }
            set { var psSizeOverLifetime = ps.sizeOverLifetime; psSizeOverLifetime.size = value; }
        }

        public Overlay(Transform transform)
        {
            this.Transform = transform;

            GameObject = transform.gameObject;
            ps = transform.GetComponentInChildren<ParticleSystem>();
            psr = transform.GetComponentInChildren<ParticleSystemRenderer>();
            psm = ps.main;
        }
    }
}
