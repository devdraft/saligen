from setuptools import setup, find_packages

with open("README.md", "r", encoding="utf-8") as fh:
    long_description = fh.read()

setup(
    name="devdraft-sdk",
    version="0.1.0",
    author="devdraft",
    author_email="engineering@devdraft.ai",
    description="Python SDK for DevDraft API with production-ready features",
    long_description=long_description,
    long_description_content_type="text/markdown",
    url="https://github.com/yourorg/yourapi-python",
    packages=find_packages(),
    classifiers=[
        "Development Status :: 4 - Beta",
        "Intended Audience :: Developers",
        "License :: OSI Approved :: MIT License",
        "Programming Language :: Python :: 3",
        "Programming Language :: Python :: 3.8",
        "Programming Language :: Python :: 3.9",
        "Programming Language :: Python :: 3.10",
        "Programming Language :: Python :: 3.11",
        "Programming Language :: Python :: 3.12",
    ],
    python_requires=">=3.8",
    install_requires=[
        "urllib3>=2.0.0",
    ],
    extras_require={
        "dev": [
            "pytest>=7.0.0",
            "pytest-cov>=4.0.0",
            "black>=23.0.0",
            "mypy>=1.0.0",
            "ruff>=0.1.0",
        ],
    },
    keywords="devdraft devdraft-sdk sdk api-client python",
    project_urls={
        "Bug Reports": "https://github.com/yourorg/yourapi-python/issues",
        "Source": "https://github.com/yourorg/yourapi-python",
        "Documentation": "https://docs.yourorg.com",
    },
)

